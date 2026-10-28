// Next declares static image imports in next-env.d.ts, which `next build`
// writes and the repository does not carry; `tsc` on a fresh checkout reads
// the same declaration for the SVG logo from here.
declare module "*.svg" {
  const content: import("next/image").StaticImageData;
  export default content;
}
