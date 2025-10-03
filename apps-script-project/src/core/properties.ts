/**
 * @summary Lấy thuộc tính từ dịch vụ thuộc tính của tập lệnh
 * @param {string} key
 * @returns {string}
 */
export const getScriptProperty = (key: string): string => {
  const properties = PropertiesService.getScriptProperties();
  const value = properties.getProperty(key);
  if (!value) {
    throw new Error(`Không tìm thấy thuộc tính tập lệnh cho khóa: ${key}`);
  }
  return value;
};

/**
 * @summary Đặt thuộc tính cho dịch vụ thuộc tính của tập lệnh
 * @param {string} key
 * @param {string} value
 */
export const setScriptProperty = (key: string, value: string): void => {
  const properties = PropertiesService.getScriptProperties();
  properties.setProperty(key, value);
};
