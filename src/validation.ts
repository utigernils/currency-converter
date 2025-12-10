export function isCurrency(currency: string): boolean {
  const currencyCode = /^[a-z]{3}$/;
  return currencyCode.test(currency);
}
