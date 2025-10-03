Dựa trên thông tin từ các nguồn về việc tích hợp API KiotViet, quá trình lấy **Access Token** được thực hiện thông qua cơ chế xác thực **OAuth 2.0** bằng cách gửi một yêu cầu **POST** đến Endpoint Token của KiotViet.

Access Token này là cần thiết để truy cập vào hầu hết các API khác của KiotViet (trừ API lấy token và Authentication Code).

Dưới đây là hướng dẫn chi tiết các bước thực hiện:

## I. Các thông tin cần thiết

Để lấy Access Token, bạn cần có hai thông tin cấu hình quan trọng mà KiotViet API xác thực dựa trên đó: **ClientId** và **Mã bảo mật (client\_secret)**.

Các thông tin cấu hình đã được đề cập trong nguồn ví dụ bao gồm:

| Tên cấu hình | Giá trị | Nguồn |
| :--- | :--- | :--- |
| **Retailer** (Tên gian hàng) | `phanphoisongiasi` | |
| **client\_id** | `ca70d033-6a44-4ad1-bbec-d142616ede22` | |
| **client\_secret** | `EFDECA4A7AC13D65ED054DA26533F7016DDB6C9C` | |

Bạn có thể tìm thấy thông tin ClientId và Mã bảo mật bằng cách truy cập vào **"Thiết lập cửa hàng"** bằng tài khoản admin và chọn **"Thiết lập kết nối API"**.

## II. Thực hiện gọi API để lấy Access Token

Bạn sẽ thực hiện một yêu cầu **POST** đến Endpoint Token của KiotViet:

### 1. Endpoint và Phương thức

*   **Phương thức:** `POST`
*   **URL (Token Endpoint):** `https://id.kiotviet.vn/connect/token`

### 2. Header (Tiêu đề Request)

Yêu cầu cần có Header để chỉ định định dạng dữ liệu gửi đi:

| Header | Giá trị |
| :--- | :--- |
| **Content-Type** | `application/x-www-form-urlencoded` |

### 3. Body (Dữ liệu Request)

Yêu cầu cần truyền các tham số sau trong phần Body (dạng form URL-encoded):

| Tham số | Giá trị | Mục đích |
| :--- | :--- | :--- |
| **scopes** | `PublicApi.Access` | Phạm vi truy cập (chỉ định bạn muốn truy cập Public API). |
| **grant\_type** | `client_credentials` | Thông tin truy cập dạng token. |
| **client\_id** | `{ClientId của bạn}` | Client ID đã lấy từ cấu hình. |
| **client\_secret** | `{Client Secret của bạn}` | Mã bảo mật đã lấy từ cấu hình. |

**Ví dụ Body mẫu được cung cấp:**

```
scopes=PublicApi.Access&grant_type=client_credentials&client_id=e4fe37ab-5d10-4919-bf59-d9a568456d0b&client_secret=01A3703244752CFF6350A801F900742179C7CCDA
```

### 4. Response (Phản hồi)

Nếu yêu cầu thành công, API sẽ trả về phản hồi JSON chứa Access Token và thời gian hết hạn:

```json
{
"access_token": "...", // Mã Access Token bạn cần
"expires_in": 86400, // Thời gian hết hạn tính bằng giây (ví dụ: 86400 giây = 24 giờ)
"token_type": "Bearer" // Loại token
}
```

## III. Sử dụng Access Token

Sau khi có được `access_token`, bạn phải sử dụng mã này trong **Header** của tất cả các yêu cầu API KiotViet khác.

Header cho các API tiếp theo sẽ bao gồm:

1.  **"Retailer":** Tên gian hàng (ví dụ: `phanphoisongiasi`).
2.  **"Authorization":** `Bearer {Mã Access Token}`.

**Ví dụ về Header Authorization:**

`Authorization: Bearer eyJhbGciOiJSU0EtT0FFUCIsImVu……………………..Z31gSjq6REOpMUj3hBYBojekzw`