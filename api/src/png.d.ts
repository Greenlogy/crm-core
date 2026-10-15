// Obrázky pribalené do Workera (wrangler.toml: [[rules]] type = "Data")
declare module '*.png' {
  const data: ArrayBuffer;
  export default data;
}
