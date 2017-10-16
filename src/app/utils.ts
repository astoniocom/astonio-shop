export function round(value:number, digits=1):number {
  return parseFloat(value.toFixed(digits))
}