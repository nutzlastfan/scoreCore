const trimTrailingSlash = (value: string) => value.replace(/\/+$/, "");
const trimSlashes = (value: string) => value.replace(/^\/+|\/+$/g, "");

export const getBackendBaseUrl = () => {
  return trimTrailingSlash(process.env.REACT_APP_BACKEND_URL || "");
};

export const backendUrl = (...parts: Array<string | number | undefined | null>) => {
  const cleanParts = parts
    .filter((part) => part !== undefined && part !== null && `${ part }` !== "")
    .map((part) => `${ part }`);
  const hasTrailingSlash = cleanParts.length > 0 && cleanParts[cleanParts.length - 1].endsWith("/");
  const path = cleanParts
    .map((part) => trimSlashes(part))
    .filter((part) => part !== "")
    .join("/");

  const pathWithSlash = `/${ path }${ hasTrailingSlash && path ? "/" : "" }`;
  const baseUrl = getBackendBaseUrl();
  return baseUrl ? `${ baseUrl }${ pathWithSlash }` : pathWithSlash;
};

export const wsUrl = (path: string) => {
  const configured = process.env.REACT_APP_BASE_WS || process.env.REACT_APP_WS_URL || "";
  const baseUrl = configured
    ? trimTrailingSlash(configured)
    : `${ window.location.protocol === "https:" ? "wss:" : "ws:" }//${ window.location.host }`;

  return `${ baseUrl }/${ trimSlashes(path) }`;
};
