Dựa trên các nguồn thông tin được cung cấp, dưới đây là danh sách các nhóm API công khai (**Public API**) của KiotViet được sử dụng để tích hợp và trao đổi dữ liệu (đọc/ghi):

API Public của KiotViet được phát triển để hỗ trợ việc tích hợp và trao đổi dữ liệu giữa KiotViet với các nền tảng khác như website, thương mại điện tử, CRM....

---

### **Danh sách các nhóm API KiotViet**

#### **1. Xác thực (Authentication)**

KiotViet API xác thực dựa trên cơ chế **OAuth 2.0**.

*   **Lấy thông tin Access Token:** Được sử dụng để truy cập các API khác.
    *   Phương thức và URL: `POST https://id.kiotviet.vn/connect/token`.
    *   Thông tin cần thiết để lấy Access Token bao gồm **Retailer**, **client\_id**, và **client\_secret**.

#### **2. Quản lý Hàng hóa và Danh mục**

| Đối tượng | Chức năng (APIs) | Tham chiếu |
| :--- | :--- | :--- |
| **Hàng hóa** (`/products`) | Lấy danh sách hàng hóa; Lấy chi tiết hàng hóa (theo ID hoặc Code); Thêm mới hàng hóa; Cập nhật hàng hóa; Xóa hàng hóa. |,,,, |
| **Nhóm hàng** (`/categories`) | Lấy danh sách nhóm hàng (tối đa 3 cấp); Lấy chi tiết nhóm hàng; Thêm mới nhóm hàng; Cập nhật nhóm hàng; Xóa nhóm hàng. |,,,, |
| **Tồn kho** (`/productOnHands`) | Lấy danh sách tồn kho hàng hóa. | |
| **Thuộc tính sản phẩm** (`/attributes/allwithdistinctvalue`) | Lấy toàn bộ thông tin thuộc tính của tất cả các sản phẩm. | |
| **Thương hiệu** (`/trademark`) | Lấy danh sách thương hiệu của hàng hóa. | |
| **Thao tác hàng loạt (Bulk)** | Thêm mới danh sách hàng hóa (`/listaddproducts`); Cập nhật danh sách hàng hóa (`/listupdatedproducts`). |, |

#### **3. Quản lý Giao dịch Bán hàng (Đơn hàng & Hóa đơn)**

| Đối tượng | Chức năng (APIs) | Tham chiếu |
| :--- | :--- | :--- |
| **Đặt hàng** (`/orders`) | Lấy danh sách đặt hàng; Lấy chi tiết đặt hàng (theo ID hoặc Code); Thêm mới đặt hàng; Cập nhật đặt hàng; Xóa đặt hàng. |,,,, |
| **Hóa đơn** (`/invoices`) | Lấy danh sách hóa đơn; Lấy chi tiết hóa đơn (theo ID hoặc Code); Thêm mới hóa đơn; Cập nhật hóa đơn; Xóa hóa đơn. |,,,, |
| **Trả hàng** (`/returns`) | Lấy danh sách trả hàng; Lấy chi tiết phiếu trả hàng. |, |
| **Kênh bán hàng** (`/salechannel`) | Lấy danh sách kênh bán hàng. | |

#### **4. Quản lý Khách hàng (Customers)**

| Đối tượng | Chức năng (APIs) | Tham chiếu |
| :--- | :--- | :--- |
| **Khách hàng** (`/customers`) | Lấy danh sách khách hàng; Lấy chi tiết khách hàng (theo ID hoặc Code); Thêm mới khách hàng; Cập nhật khách hàng; Xóa khách hàng. |,,,, |
| **Nhóm khách hàng** (`/customers/group`) | Lấy danh sách nhóm khách hàng. | |
| **Thao tác hàng loạt (Bulk)** | Thêm mới danh sách khách hàng (`/listaddcutomers`); Cập nhật danh sách khách hàng (`/listupdatecustomers`). |, |

#### **5. Quản lý Nhập hàng và Nhà cung cấp**

| Đối tượng | Chức năng (APIs) | Tham chiếu |
| :--- | :--- | :--- |
| **Phiếu nhập hàng** (`/purchaseorders`) | Lấy danh sách nhập hàng; Lấy chi tiết nhập hàng; Thêm mới nhập hàng; Cập nhật nhập hàng; Xóa nhập hàng. |,,,, |
| **Đặt hàng nhập** (`/ordersuppliers`) | Lấy danh sách đặt hàng nhập; Lấy chi tiết đặt hàng nhập. |, |
| **Nhà cung cấp** (`/suppliers`) | Lấy danh sách nhà cung cấp; Lấy chi tiết nhà cung cấp (theo ID hoặc Code). |, |

#### **6. Quản lý Hệ thống và Nội bộ (Phụ trợ)**

Các API này thường được gọi là "Các API phụ trợ" và bao gồm:

*   **Chi nhánh** (`/branches`): Lấy danh sách toàn bộ chi nhánh.
*   **Người dùng** (`/users`): Lấy danh sách toàn bộ người dùng.
*   **Tài khoản ngân hàng** (`/BankAccounts`): Lấy danh sách toàn bộ tài khoản ngân hàng.
*   **Thu khác** (`/surchages`): Lấy danh sách thu khác; Thêm mới thu khác; Cập nhật thu khác; Ngừng hoạt động thu khác.
*   **Sổ quỹ** (`/cashflow`): Lấy danh sách phiếu thu chi trong sổ quỹ; Thanh toán hóa đơn.
*   **Location** (`/locations`): Trả về thông tin location (ví dụ: tỉnh/thành phố).
*   **Thiết lập cửa hàng** (`/settings`): Trả về danh sách thiết lập cửa hàng.
*   **Chuyển hàng** (`/transfers`): Lấy danh sách chuyển hàng; Lấy chi tiết; Thêm mới; Cập nhật; Xóa phiếu chuyển hàng.

#### **7. Khuyến mại và Giá cả**

*   **Bảng giá** (`/pricebooks`): Lấy danh sách bảng giá; Lấy chi tiết bảng giá; Cập nhật chi tiết bảng giá.
*   **Voucher** (`/vouchercampaign`, `/voucher`): Lấy danh sách đợt phát hành voucher; Lấy danh sách voucher trong đợt phát hành; Tạo mới voucher; Phát hành voucher (tặng); Hủy voucher.
*   **Coupon** (`/coupons/setused`): Cập nhật trạng thái Coupon về "Đã sử dụng".

#### **8. Webhook**

Webhook là cơ chế cho phép KiotViet chủ động gọi đến server bên thứ ba khi có thay đổi xảy ra (mô hình data push).

*   **Quản lý Webhook:** Đăng ký Webhook; Hủy đăng ký Webhook; Lấy danh sách webhook; Lấy chi tiết webhook.
*   **Sự kiện Webhook (ví dụ):**
    *   `customer.update` và `customer.delete` (Khách hàng).
    *   `product.update` và `product.delete` (Hàng hóa).
    *   `invoice.update` (Hóa đơn).
    *   `pricebook.update` và `pricebook.delete` (Bảng giá).
    *   `stock.update` (Tồn kho).
    *   `order.update` (Đặt hàng).
    *   `category.update` và `category.delete` (Danh mục hàng hóa).
    *   `branch.update` và `branch.delete` (Chi nhánh).