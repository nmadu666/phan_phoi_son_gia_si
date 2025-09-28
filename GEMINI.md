Tệp `GEMINI.md` này được xây dựng dựa trên lộ trình phát triển và cấu hình kỹ thuật đã được xác định cho **Ứng dụng POS ngành sơn** (mô phỏng theo KiotViet và Flutter).

***

# GEMINI.md: Ứng Dụng POS Ngành Sơn (Dựa trên KiotViet & Flutter)

Tệp này tóm tắt chiến lược phát triển, cấu trúc kiến trúc và cấu hình kỹ thuật nhằm hỗ trợ Gemini Assist Code trong VSC.

## I. Tổng Quan Dự Án

Mục tiêu cốt lõi của dự án là xây dựng một ứng dụng **POS (Point of Sale)** chuyên biệt cho ngành sơn. Ứng dụng này mô phỏng giao diện hiện đại của KiotViet và được thiết kế để tích hợp sâu các luồng nghiệp vụ pha màu phức tạp, đồng thời tối ưu hóa cấu trúc dữ liệu để đồng bộ với **KiotViet API**. Mục tiêu kiến trúc là tối ưu hóa việc **bảo trì, khả năng mở rộng** và **làm việc nhóm**.

| Thuộc tính | Chi tiết | Nguồn |
| :--- | :--- | :--- |
| **Nền tảng** | Flutter (hỗ trợ Desktop/Web, Mobile) | |
| **Backend Chính** | KiotViet API (đồng bộ dữ liệu) và Firestore (lưu trữ logic tính giá) | |
| **Nghiệp vụ đặc thù** | Tích hợp luồng nghiệp vụ pha màu phức tạp và logic tính giá riêng của ngành sơn | |

## II. Cấu Trúc Dự Án & Nguyên Tắc Cốt Lõi

### 1. Nguyên Tắc Kiến Trúc

Dự án Flutter này tuân thủ nguyên tắc cốt lõi **"Feature-First" (Ưu tiên Tính năng)**.

*   **Định nghĩa:** Mỗi tính năng được xem là một **"module" gần như độc lập**, chứa đựng tất cả các thành phần cần thiết để hoạt động, bao gồm UI, logic trạng thái, và các hàm xử lý dữ liệu riêng.
*   **Lợi ích:** Cấu trúc này giúp **dễ tìm kiếm** (tìm bug/sửa), **dễ bảo trì** (thay đổi một feature ít ảnh hưởng đến các feature khác), **dễ mở rộng** (thêm feature mới chỉ cần tạo thư mục mới), và hỗ trợ **làm việc nhóm** hiệu quả.
*   **Cấu trúc Thư mục Lõi:** Các thư mục quan trọng bao gồm `lib/core/` (chứa các file gọi API, models dữ liệu, và các service chung như `settings_service.dart`) và `lib/features/` (chứa tất cả các tính năng).

### 2. Các Tính Năng Cốt Lõi (`features/` modules)

Các module tính năng chính được triển khai độc lập trong thư mục `features/` bao gồm:

1.  `pos_counter` (**Màn hình bán hàng chính**)
2.  `product_management` (Quản lý sản phẩm, màu sắc)
3.  `order_history` (Lịch sử đơn hàng)
4.  `customer` (Quản lý khách hàng)
5.  `settings` (Cài đặt)

### 3. Phân Tách Giao Diện (UI/UX)

Giao diện được phân tách rõ ràng để tối ưu hóa cho từng nền tảng:

| Nền tảng | Bố cục & Mục đích | Widget/Màn hình Chính | Nguồn |
| :--- | :--- | :--- | :--- |
| **Desktop** | **Bố cục 3 cột rõ ràng** (mô phỏng KiotViet), tận dụng không gian rộng cho quầy thanh toán. Hỗ trợ luồng **Product-First** và **Color-First**. | `desktop_layout.dart`, `ProductGridView`, `OrderPanel`, `CustomerSearch`. | |
| **Mobile** | Sử dụng **BottomNavigationBar**. Tối ưu cho thao tác nhanh gọn và sử dụng một tay. | `MobileProductListScreen`, `MobileColorPaletteScreen`, `MobileCreateOrderScreen`. | |

## III. Cấu Hình Kỹ Thuật (Integrations)

### 1. Cấu hình KiotViet API

Ứng dụng sử dụng **Public API của KiotViet** để trao đổi dữ liệu (đọc/ghi). Cơ chế xác thực dựa trên **OAuth 2.0**.

| Cấu hình KiotViet API | Giá trị | Mục đích | Nguồn |
| :--- | :--- | :--- | :--- |
| **Retailer** | `phanphoisongiasi` | Tên gian hàng (dùng trong Header API) | |
| **client_id** | `ca70d033-6a44-4ad1-bbec-d142616ede22` | Client ID cho OAuth 2.0 | |
| **client_secret** | `EFDECA4A7AC13D65ED054DA26533F7016DDB6C9C` | Mã bảo mật cho OAuth 2.0 | |

Ứng dụng cần sử dụng các API cơ bản như: **Hàng hóa** (lấy thông tin sản phẩm, tạo mới), **Đặt hàng/Hóa đơn** (tạo đơn, lấy danh sách), **Khách hàng** (lấy danh sách, thao tác trên thông tin), và **Lấy thông tin Access Token** (Authenticate).

### 2. Mô hình Dữ liệu Firestore (Cập nhật v7.0)

Cấu trúc dữ liệu trên Firestore được điều chỉnh để hỗ trợ Logic Tính Giá Pha Màu:

| Collection | Mục đích | Cấu trúc Dữ liệu Chính (Bao gồm) | Nguồn |
| :--- | :--- | :--- | :--- |
| `products` | Lưu trữ Sản phẩm sơn gốc, đồng bộ từ KiotViet. | `variants` (SKU) chứa **`kiotVietId`** (ID hàng hóa trên KiotViet), **`kiotVietCode`**, **`volumeLiters`** (dung tích thực), `basePrice`, và `baseType`. | |
| `colors` | Thư viện màu sắc. | `code`, `name`, `hexCode`, và quan trọng là `colorPricings`. `colorPricings` chứa **`pricePerMl`** (đơn giá/hệ số giá cho công thức pha màu), `qualityGrade`, và `baseType`. | |
| `orders` | Lưu trữ thông tin đơn hàng. | Cấu trúc không đổi. | |

### 3. Logic Tính Giá Cốt Lõi (Ngành Sơn)

Ứng dụng sử dụng **Logic Tính Giá Linh Hoạt** (Flexible Pricing Logic):

$$\text{Giá cuối} = \text{Giá Sơn Gốc} + \text{Chi Phí Tinh Màu}$$

Trong đó, **Chi Phí Tinh Màu** được tính bằng công thức sau:

$$\text{Chi Phí Tinh Màu} = \text{pricePerMl} \times \text{volumeLiters} \times \text{hệ số} \times 1000$$

*   **`pricePerMl`**: Đơn giá/hệ số giá, lấy từ collection `colors`.
*   **`volumeLiters`**: Dung tích thực của sản phẩm, lấy từ `variants` trong collection `products`.
*   **`hệ số`**: Một biến số do cửa hàng tự cấu hình, được quản lý thông qua `settings_service.dart`.

## IV. Lộ Trình Phát Triển (Roadmap)

Lộ trình phát triển được chia thành 4 giai đoạn chính:

| Giai đoạn | Tên Giai Đoạn | Hành động Chính (Actions) | Nguồn |
| :--- | :--- | :--- | :--- |
| **1** | **Xây "Móng Nhà" - Backend & Core Logic** | Thiết lập Flutter/Firebase, tạo các service cốt lõi (như `kiotviet_api_service.dart` và `order_service.dart` chứa hàm tính giá) để ứng dụng có thể đọc, ghi và xử lý dữ liệu. | |
| **2** | **Xây "Khung Tường" - Giao Diện (UI)** | Dựng giao diện người dùng mô phỏng KiotViet. Xây dựng bố cục 3 cột cho Desktop (`desktop_layout.dart`) và các màn hình chuyên biệt cho Mobile (sử dụng `BottomNavigationBar`). | |
| **3** | **Lắp "Điện Nước" - Kết Nối UI và Logic** | Lập trình logic giỏ hàng (tính toán lại tổng tiền). Hoàn thiện luồng thanh toán: chốt giá (qua `order_service`) và **đẩy đơn hàng về KiotViet** (qua `kiotviet_api_service`). | |
| **4** | **Hoàn Thiện & Tối Ưu** | Tích hợp tìm kiếm nâng cao (ví dụ: Algolia/Typesense). Xây dựng màn hình "Cài đặt" để tùy chỉnh hệ số. Phát triển các tính năng phụ trợ (lịch sử đơn hàng, quản lý công nợ) và triển khai ứng dụng. | |