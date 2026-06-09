package com.studiophoto.photoappbackend.order;

import com.studiophoto.photoappbackend.dimension.Dimension;
import com.studiophoto.photoappbackend.dimension.DimensionRepository;
import com.studiophoto.photoappbackend.frame.PhotoFrame;
import com.studiophoto.photoappbackend.frame.PhotoFrameRepository;
import com.studiophoto.photoappbackend.model.User;
import com.studiophoto.photoappbackend.notification.UserNotificationService;
import jakarta.transaction.Transactional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.net.URL;
import java.util.zip.ZipEntry;
import java.util.zip.ZipOutputStream;
import java.math.BigDecimal;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.stream.Collectors;

@Service
@RequiredArgsConstructor
@Slf4j
public class OrderService {

    private final OrderRepository orderRepository;
    private final DimensionRepository dimensionRepository;
    private final PhotoFrameRepository photoFrameRepository;
    private final UserNotificationService userNotificationService;

    @Transactional
    public Order createOrder(CreateOrderRequest request, User user) {
        Map<String, Dimension> dimensionMap = dimensionRepository.findAll().stream()
                .collect(Collectors.toMap(Dimension::getName, dimension -> dimension));

        // 2. Créer l'objet Order principal
        Order newOrder = Order.builder()
                .user(user)
                .paymentMethod(request.getPaymentMethod())
                .deliveryType(request.isExpress() ? "Xpress" : "Standard")
                .deliveryAddress(request.getDeliveryAddress()) // Set delivery address
                .status(OrderStatus.PENDING_PAYMENT)
                .paymentStatus("PENDING_PAYMENT")
                .build();

        // 3. Créer les OrderItems et calculer le sous-total
        BigDecimal subtotal = BigDecimal.ZERO;
        for (CreateOrderItemRequest itemRequest : request.getItems()) {
            if (itemRequest.getImageUrl() == null || itemRequest.getImageUrl().isBlank()) {
                throw new IllegalArgumentException(
                        "L'URL de l'image ne peut pas être nulle ou vide pour un article de commande.");
            }
            if (itemRequest.getSize() == null) {
                throw new IllegalArgumentException(
                        "Le format de photo ne peut pas être nul pour un article de commande.");
            }
            Dimension dimension = dimensionMap.get(itemRequest.getSize());
            if (dimension == null) {
                throw new IllegalArgumentException(
                        "Le format de photo '" + itemRequest.getSize() + "' n'est pas valide.");
            }
            BigDecimal pricePerUnit = dimension.getPrice();
            boolean withFrame = Boolean.TRUE.equals(itemRequest.getWithFrame());
            BigDecimal framePrice = BigDecimal.ZERO;
            Long frameId = null;
            String frameName = null;
            String frameImageUrl = null;

            if (withFrame) {
                if (dimension.getFramePrice() == null
                        || dimension.getFramePrice().compareTo(BigDecimal.ZERO) <= 0) {
                    throw new IllegalArgumentException(
                            "Le cadre n'est pas disponible pour le format '" + itemRequest.getSize() + "'.");
                }
                if (itemRequest.getFrameId() == null) {
                    throw new IllegalArgumentException(
                            "Veuillez sélectionner un style de cadre pour le format '" + itemRequest.getSize() + "'.");
                }
                PhotoFrame frame = photoFrameRepository.findById(itemRequest.getFrameId())
                        .orElseThrow(() -> new IllegalArgumentException("Style de cadre invalide."));
                if (!frame.isActive()) {
                    throw new IllegalArgumentException("Le style de cadre sélectionné n'est plus disponible.");
                }
                framePrice = dimension.getFramePrice();
                frameId = frame.getId();
                frameName = frame.getName();
                frameImageUrl = primaryFrameImage(frame);
            }

            OrderItem orderItem = OrderItem.builder()
                    .imageUrl(itemRequest.getImageUrl())
                    .photoSize(itemRequest.getSize())
                    .quantity(itemRequest.getQuantity())
                    .pricePerUnit(pricePerUnit)
                    .withFrame(withFrame)
                    .frameId(frameId)
                    .frameName(frameName)
                    .frameImageUrl(frameImageUrl)
                    .framePrice(framePrice)
                    .studioPrintAdvice(trimToNull(itemRequest.getStudioPrintAdvice()))
                    .suggestedPhotoSize(trimToNull(itemRequest.getSuggestedPhotoSize()))
                    .chosenPrintQuality(trimToNull(itemRequest.getChosenPrintQuality()))
                    .suggestedPrintQuality(trimToNull(itemRequest.getSuggestedPrintQuality()))
                    .build();

            newOrder.addOrderItem(orderItem);
            BigDecimal lineUnitTotal = pricePerUnit.add(framePrice);
            subtotal = subtotal.add(lineUnitTotal.multiply(new BigDecimal(itemRequest.getQuantity())));
        }

        // 4. Ajouter les frais de livraison si nécessaire
        BigDecimal totalAmount = subtotal;
        if (request.isExpress() && request.getItems().size() <= 10) {
            totalAmount = totalAmount.add(new BigDecimal("1500"));
        }

        newOrder.setTotalAmount(totalAmount);

        String newOrderFingerprint = buildRequestFingerprint(request, dimensionMap, totalAmount);
        LocalDateTime duplicateWindowStart = LocalDateTime.now().minusMinutes(3);
        List<Order> recentOrders = orderRepository.findByUserIdAndCreatedAtAfterOrderByCreatedAtDesc(
                user.getId(),
                duplicateWindowStart
        );

        boolean duplicateExists = recentOrders.stream()
                .filter(existing -> existing.getStatus() != OrderStatus.CANCELLED)
                .filter(existing -> existing.getOrderItems() != null && !existing.getOrderItems().isEmpty())
                .anyMatch(existing -> buildOrderFingerprint(existing).equals(newOrderFingerprint));

        if (duplicateExists) {
            throw new IllegalStateException(
                    "Une commande identique vient deja d'etre creee il y a quelques instants. Verifiez votre historique avant de recommencer.");
        }

        // 5. Sauvegarder la commande (et les OrderItems grâce à CascadeType.ALL)
        Order saved = orderRepository.save(newOrder);
        userNotificationService.notifyOrderCreated(saved);
        return saved;
    }

    private String buildRequestFingerprint(
            CreateOrderRequest request,
            Map<String, Dimension> dimensionMap,
            BigDecimal totalAmount) {
        String normalizedPaymentMethod = normalizeText(request.getPaymentMethod());
        String normalizedDeliveryType = request.isExpress() ? "xpress" : "standard";
        String normalizedAddress = normalizeText(request.getDeliveryAddress());

        String itemsFingerprint = request.getItems().stream()
                .map(item -> {
                    Dimension dimension = dimensionMap.get(item.getSize());
                    BigDecimal pricePerUnit = dimension != null ? dimension.getPrice() : BigDecimal.ZERO;
                    BigDecimal framePrice = Boolean.TRUE.equals(item.getWithFrame()) && dimension != null
                            && dimension.getFramePrice() != null
                            ? dimension.getFramePrice()
                            : BigDecimal.ZERO;
                    return String.join("|",
                            normalizeText(item.getImageUrl()),
                            normalizeText(item.getSize()),
                            String.valueOf(item.getQuantity()),
                            normalizeAmount(pricePerUnit),
                            String.valueOf(Boolean.TRUE.equals(item.getWithFrame())),
                            normalizeAmount(framePrice),
                            item.getFrameId() == null ? "" : String.valueOf(item.getFrameId()));
                })
                .sorted()
                .collect(Collectors.joining(";"));

        return String.join("||",
                normalizedPaymentMethod,
                normalizedDeliveryType,
                normalizedAddress,
                normalizeAmount(totalAmount),
                itemsFingerprint);
    }

    private String buildOrderFingerprint(Order order) {
        String normalizedPaymentMethod = normalizeText(order.getPaymentMethod());
        String normalizedDeliveryType = normalizeText(order.getDeliveryType());
        String normalizedAddress = normalizeText(order.getDeliveryAddress());

        String itemsFingerprint = order.getOrderItems().stream()
                .sorted(Comparator.comparing(item -> item.getId() == null ? 0L : item.getId()))
                .map(item -> String.join("|",
                        normalizeText(item.getImageUrl()),
                        normalizeText(item.getPhotoSize()),
                        String.valueOf(item.getQuantity()),
                        normalizeAmount(item.getPricePerUnit()),
                        String.valueOf(item.isWithFrame()),
                        normalizeAmount(item.getFramePrice()),
                        item.getFrameId() == null ? "" : String.valueOf(item.getFrameId())))
                .sorted()
                .collect(Collectors.joining(";"));

        return String.join("||",
                normalizedPaymentMethod,
                normalizedDeliveryType,
                normalizedAddress,
                normalizeAmount(order.getTotalAmount()),
                itemsFingerprint);
    }

    private String primaryFrameImage(PhotoFrame frame) {
        if (frame.getImages() == null || frame.getImages().isBlank()) {
            return null;
        }
        return java.util.Arrays.stream(frame.getImages().split(","))
                .map(String::trim)
                .filter(s -> !s.isEmpty())
                .findFirst()
                .orElse(null);
    }

    private String normalizeText(String value) {
        return value == null ? "" : value.trim().toLowerCase();
    }

    private String normalizeAmount(BigDecimal value) {
        return value == null ? "0" : value.stripTrailingZeros().toPlainString();
    }

    @Transactional
    public Order updateOrderStatusAndPaymentMethod(Long orderId, OrderStatus status, String paymentMethod) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        if (status == OrderStatus.CANCELLED && isPaidProcessingOrder(order)) {
            if (order.getRefundStatus() == RefundStatus.REFUND_PENDING) {
                throw new IllegalStateException(
                        "Remboursement en cours. Confirmez le remboursement USSD avant de clôturer l'annulation.");
            }
            if (order.getRefundStatus() != RefundStatus.REFUNDED) {
                throw new IllegalStateException(
                        "Impossible d'annuler une commande payée sans passer par le flux de remboursement.");
            }
        }

        if (status == OrderStatus.COMPLETED) {
            if (order.getRefundStatus() == RefundStatus.REFUND_PENDING) {
                throw new IllegalStateException(
                        "Impossible de terminer la commande : un remboursement est en cours.");
            }
            if (order.getStatus() != OrderStatus.PROCESSING) {
                throw new IllegalStateException(
                        "Seules les commandes en traitement (payées) peuvent être marquées terminées.");
            }
        }

        OrderStatus previousStatus = order.getStatus();
        order.setStatus(status);

        // If the order becomes PROCESSING, it means payment is confirmed
        if (status == OrderStatus.PROCESSING) {
            order.setPaymentStatus("PAID");
        }

        if (paymentMethod != null) {
            order.setPaymentMethod(paymentMethod);
        }
        Order saved = orderRepository.save(order);
        userNotificationService.onOrderStatusUpdated(saved, previousStatus, status);
        return saved;
    }

    private boolean isPaidProcessingOrder(Order order) {
        return order.getStatus() == OrderStatus.PROCESSING
                && order.getPaymentStatus() != null
                && "PAID".equalsIgnoreCase(order.getPaymentStatus());
    }

    private String currentAdminUsername() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !auth.isAuthenticated()) {
            return "admin";
        }
        return auth.getName();
    }

    /**
     * Initie un remboursement manuel (USSD). Possible uniquement tant que la commande est en PROCESSING.
     */
    @Transactional
    public Order initiateRefund(Long orderId, BigDecimal refundAmount, String refundReason) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        if (order.getStatus() != OrderStatus.PROCESSING) {
            throw new IllegalStateException(
                    "Le remboursement n'est possible que pour une commande en traitement (non terminée).");
        }
        if (!isPaidProcessingOrder(order)) {
            throw new IllegalStateException("Cette commande n'est pas considérée comme payée.");
        }
        if (order.getRefundStatus() == RefundStatus.REFUND_PENDING) {
            throw new IllegalStateException("Un remboursement est déjà en cours pour cette commande.");
        }
        if (order.getRefundStatus() == RefundStatus.REFUNDED) {
            throw new IllegalStateException("Cette commande a déjà été remboursée.");
        }

        BigDecimal amount = refundAmount != null ? refundAmount : order.getTotalAmount();
        if (amount == null || amount.compareTo(BigDecimal.ZERO) <= 0) {
            throw new IllegalArgumentException("Le montant du remboursement doit être supérieur à zéro.");
        }
        if (order.getTotalAmount() != null && amount.compareTo(order.getTotalAmount()) > 0) {
            throw new IllegalArgumentException(
                    "Le montant du remboursement ne peut pas dépasser le total de la commande.");
        }

        String reason = refundReason != null ? refundReason.trim() : "";
        if (order.getTotalAmount() != null
                && amount.compareTo(order.getTotalAmount()) < 0
                && reason.isEmpty()) {
            throw new IllegalArgumentException(
                    "Un motif est obligatoire pour un remboursement partiel (à communiquer au client).");
        }

        order.setRefundStatus(RefundStatus.REFUND_PENDING);
        order.setRefundAmount(amount);
        order.setRefundReason(reason.isEmpty() ? null : reason);
        order.setRefundReference(null);
        order.setRefundedAt(null);
        order.setRefundedBy(currentAdminUsername());

        Order saved = orderRepository.save(order);
        userNotificationService.notifyRefundPending(saved);
        return saved;
    }

    /**
     * Confirme le remboursement après envoi USSD manuel vers le client.
     */
    @Transactional
    public Order confirmRefund(Long orderId, String refundReference) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        if (order.getRefundStatus() != RefundStatus.REFUND_PENDING) {
            throw new IllegalStateException("Aucun remboursement en attente pour cette commande.");
        }

        String reference = refundReference != null ? refundReference.trim() : "";
        if (reference.isEmpty()) {
            throw new IllegalArgumentException("La référence de transaction du remboursement est obligatoire.");
        }

        order.setRefundStatus(RefundStatus.REFUNDED);
        order.setRefundReference(reference);
        order.setRefundedAt(LocalDateTime.now());
        order.setRefundedBy(currentAdminUsername());
        order.setPaymentStatus("REFUNDED");
        order.setStatus(OrderStatus.CANCELLED);

        Order saved = orderRepository.save(order);
        userNotificationService.notifyRefundConfirmed(saved);
        return saved;
    }

    @Transactional
    public Order markPaymentReportedByCustomer(
            Long orderId,
            User user,
            String paymentReference,
            String paymentProofType,
            String paymentProofText,
            String paymentProofImageUrl) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        if (!order.getUser().getId().equals(user.getId())) {
            throw new IllegalStateException("Vous n'êtes pas autorisé à confirmer le paiement de cette commande.");
        }
        if (order.getStatus() == OrderStatus.CANCELLED || order.getStatus() == OrderStatus.COMPLETED) {
            throw new IllegalStateException("Cette commande ne peut plus être confirmée.");
        }

        order.setStatus(OrderStatus.PENDING_PAYMENT);
        order.setPaymentStatus("CUSTOMER_REPORTED_PAID");
        if (paymentReference != null && !paymentReference.isBlank()) {
            order.setPaymentReference(paymentReference.trim());
        }
        if (paymentProofType != null && !paymentProofType.isBlank()) {
            order.setPaymentProofType(paymentProofType.trim());
        }
        if (paymentProofText != null && !paymentProofText.isBlank()) {
            order.setPaymentProofText(paymentProofText.trim());
        }
        if (paymentProofImageUrl != null && !paymentProofImageUrl.isBlank()) {
            order.setPaymentProofImageUrl(paymentProofImageUrl.trim());
        }
        Order saved = orderRepository.save(order);
        userNotificationService.notifyPaymentUnderReview(saved);
        return saved;
    }

    public List<Order> findOrdersByUser(Integer userId) {
        return orderRepository.findByUserIdOrderByCreatedAtDesc(userId);
    }

    public List<Order> findAll() {
        return orderRepository.findAllByOrderByCreatedAtDesc();
    }

    @Transactional
    public void deleteById(Long id) {
        orderRepository.deleteById(id);
    }

    @Transactional
    public void deleteAllByIdIn(List<Long> ids) {
        orderRepository.deleteAllById(ids);
    }

    public Optional<Order> findById(Long id) {
        return orderRepository.findById(id);
    }

    @Transactional
    public void deletePendingPaymentOrderByCustomer(Long orderId, User user) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        if (!order.getUser().getId().equals(user.getId())) {
            throw new IllegalStateException("Vous n'êtes pas autorisé à supprimer cette commande.");
        }

        boolean waitingForClientPayment = order.getStatus() == OrderStatus.PENDING_PAYMENT
                && (order.getPaymentStatus() == null
                || "PENDING_PAYMENT".equalsIgnoreCase(order.getPaymentStatus()));

        boolean hasProof = (order.getPaymentProofImageUrl() != null && !order.getPaymentProofImageUrl().isBlank())
                || (order.getPaymentProofText() != null && !order.getPaymentProofText().isBlank())
                || (order.getPaymentProofType() != null && !order.getPaymentProofType().isBlank());

        if (!waitingForClientPayment || hasProof) {
            throw new IllegalStateException(
                    "Suppression impossible. Seules les commandes en attente de paiement (sans preuve) peuvent être supprimées.");
        }

        orderRepository.delete(order);
    }

    public byte[] createOrderPhotosZip(Long orderId, User currentUser) throws IOException {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        // Verify that the order belongs to the current user (security check)
        if (!order.getUser().getId().equals(currentUser.getId())) {
            throw new IllegalArgumentException("Vous n'êtes pas autorisé à télécharger les photos de cette commande.");
        }

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            int fileCount = 0;
            for (OrderItem item : order.getOrderItems()) {
                // Generate a unique filename for each photo in the zip
                // Using a combination of order item ID, size, and quantity
                // Plus a counter to handle multiple photos of the same item
                String originalFileName = item.getImageUrl().substring(item.getImageUrl().lastIndexOf('/') + 1);
                String entryName = String.format("%s_%s_%dx_%s",
                        order.getOrderNumber(), // Use orderNumber for better identification
                        item.getPhotoSize().replace(" ", "_"),
                        item.getQuantity(),
                        originalFileName);

                // Fetch the image from the URL
                URL url = new URL(item.getImageUrl());
                try (InputStream is = url.openStream()) {
                    zos.putNextEntry(new ZipEntry(entryName));
                    byte[] buffer = new byte[1024];
                    int len;
                    while ((len = is.read(buffer)) > 0) {
                        zos.write(buffer, 0, len);
                    }
                    zos.closeEntry();
                    fileCount++;
                } catch (IOException e) {
                    // Log the error but continue with other files
                    log.error("Failed to download image from {}: {}", item.getImageUrl(), e.getMessage());
                }
            }
            if (fileCount == 0) {
                throw new IOException("No photos were successfully added to the zip file.");
            }
        }
        return baos.toByteArray();
    }

    public byte[] createOrderPhotosZipForAdmin(Long orderId) throws IOException {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        ByteArrayOutputStream baos = new ByteArrayOutputStream();
        try (ZipOutputStream zos = new ZipOutputStream(baos)) {
            int fileCount = 0;
            for (OrderItem item : order.getOrderItems()) {
                String originalFileName = item.getImageUrl().substring(item.getImageUrl().lastIndexOf('/') + 1);
                String entryName = String.format("%s_%s_%dx_%s",
                        order.getOrderNumber(), // Use orderNumber for better identification
                        item.getPhotoSize().replace(" ", "_"),
                        item.getQuantity(),
                        originalFileName);

                // Fetch the image from the URL
                URL url = new URL(item.getImageUrl());
                try (InputStream is = url.openStream()) {
                    zos.putNextEntry(new ZipEntry(entryName));
                    byte[] buffer = new byte[1024];
                    int len;
                    while ((len = is.read(buffer)) > 0) {
                        zos.write(buffer, 0, len);
                    }
                    zos.closeEntry();
                    fileCount++;
                } catch (IOException e) {
                    // Log the error but continue with other files
                    log.error("Failed to download image from {}: {}", item.getImageUrl(), e.getMessage());
                }
            }
            if (fileCount == 0) {
                throw new IOException("No photos were successfully added to the zip file.");
            }
        }
        return baos.toByteArray();
    }

    @Transactional
    public void cancelOrder(Long orderId, User user) {
        Order order = orderRepository.findById(orderId)
                .orElseThrow(() -> new IllegalArgumentException("Commande non trouvée avec l'ID: " + orderId));

        // Check if the order belongs to the user
        if (!order.getUser().getId().equals(user.getId())) {
            throw new IllegalStateException("Vous n'êtes pas autorisé à annuler cette commande.");
        }

        // Check 48h rule
        java.time.LocalDateTime now = java.time.LocalDateTime.now();
        java.time.LocalDateTime createdAt = order.getCreatedAt();
        if (createdAt.plusHours(48).isBefore(now)) {
            throw new IllegalStateException("Le délai d'annulation de 48h est dépassé.");
        }

        if (order.getStatus() == OrderStatus.CANCELLED) {
            throw new IllegalStateException("La commande est déjà annulée.");
        }

        order.setStatus(OrderStatus.CANCELLED);
        Order saved = orderRepository.save(order);
        userNotificationService.notifyOrderCancelledByCustomer(saved);
    }

    private static String trimToNull(String value) {
        if (value == null) {
            return null;
        }
        String trimmed = value.trim();
        return trimmed.isEmpty() ? null : trimmed;
    }
}
