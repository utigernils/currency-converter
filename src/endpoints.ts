import { decodeBase64 } from "@std/encoding/base64";
import { RequestParam } from "./types.ts";
import { Converter } from "./conversion.ts";
import { err, ok } from "./http.ts";
import { isCurrency } from "./validation.ts";

export function authenticate(r: Request): boolean {
  const auth = r.headers.get("authorization") || "";
  const match = /^Basic ([A-Za-z0-9+/]+)=*$/.exec(auth);
  if (match === null) {
    return false;
  }
  const usernamePassword = new TextDecoder().decode(decodeBase64(match[1]));
  const [username, password] = usernamePassword.split(":");
  return username == credentials.username && password == credentials.password;
}

export function getRate(_req: Request, param: RequestParam): Response {
  const rate = converter.getRate(param.fromCurrency, param.toCurrency);
  if (rate === undefined) {
    const conv = `${param.fromCurrency}=>${param.toCurrency}`;
    return err({ message: `${conv}: no such exchange rate` }, 404);
  }
  return ok({ rate });
}

export function putRate(_req: Request, param: RequestParam): Response {
  if (param.value <= 0.0) {
    return err({ message: "the exchange rate must be a positive number" }, 400);
  }
  if (!isCurrency(param.fromCurrency) || !isCurrency(param.toCurrency)) {
    return err(
      { message: "currency codes must be three-letter lower-case strings" },
      400,
    );
  }
  converter.setRate(param.fromCurrency, param.toCurrency, param.value);
  return ok(undefined, 201);
}

export function deleteRate(_req: Request, param: RequestParam): Response {
  const rate = converter.getRate(param.fromCurrency, param.toCurrency);
  if (rate === undefined) {
    const conv = `${param.fromCurrency}=>${param.toCurrency}`;
    return err({ message: `${conv}: no such exchange rate` }, 404);
  }
  converter.removeRate(param.fromCurrency, param.toCurrency);
  return ok(undefined, 204);
}

export function getConversion(_req: Request, param: RequestParam): Response {
  const result = converter.convert(
    param.fromCurrency,
    param.toCurrency,
    param.value,
  );
  if (result === undefined) {
    const conv = `${param.fromCurrency}=>${param.toCurrency} ${param.value}`;
    return err({ message: `${conv} failed` });
  }
  return ok({ result });
}

const credentials = {
  username: "banker",
  password: "iLikeMoney",
};

const converter = new Converter();
