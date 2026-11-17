export const ADDON_TYPES = [
  {code:'tables',label:'Tables',unit:'table',defaultMax:20,limit:1000,maxPrice:1000},
  {code:'chairs',label:'Chairs',unit:'chair',defaultMax:200,limit:10000,maxPrice:1000},
  {code:'av',label:'AV package',unit:'booking',defaultMax:1,limit:1,maxPrice:10000},
] as const;
export type AddonCode = typeof ADDON_TYPES[number]['code'];
export type AddonCatalog = Record<AddonCode,{enabled:boolean;unit_price_cents:number;max_quantity:number;description:string}>;
export type AddonLine = {code:AddonCode;label:string;unit:string;quantity:number;unit_price_cents:number;total_cents:number;description?:string};
export function addonCatalog(raw:any = {}):AddonCatalog {
  return Object.fromEntries(ADDON_TYPES.map(d=>[d.code,{enabled:raw?.[d.code]?.enabled===true,unit_price_cents:raw?.[d.code]?.unit_price_cents??0,max_quantity:raw?.[d.code]?.max_quantity??d.defaultMax,description:raw?.[d.code]?.description??''}])) as AddonCatalog;
}
export function selectedAddonLines(catalog:AddonCatalog,quantities:Partial<Record<AddonCode,number>>):AddonLine[] {
 return ADDON_TYPES.filter(d=>catalog[d.code].enabled&&Number(quantities[d.code])>0).map(d=>({code:d.code,label:d.label,unit:d.unit,quantity:Number(quantities[d.code]),unit_price_cents:catalog[d.code].unit_price_cents,total_cents:Number(quantities[d.code])*catalog[d.code].unit_price_cents,description:catalog[d.code].description}));
}
export function bookingTotal(b:any):number {return b.total_cents??((b.subtotal_cents||0)+(b.addons_total_cents||0))}
