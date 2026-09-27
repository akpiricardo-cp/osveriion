import { cn } from "@/lib/utils";

/**
 * Le V entrelacé de VERIION. Le fichier est détouré : la marque se pose aussi
 * bien sur le bleu nuit de la barre latérale que sur un fond clair ou une
 * facture imprimée.
 */
export function LogoMark({ className }: { className?: string }) {
  return (
    // eslint-disable-next-line @next/next/no-img-element
    <img
      src="/icons/veriion-mark.png"
      alt=""
      aria-hidden
      draggable={false}
      className={cn("h-8 w-8 shrink-0 select-none object-contain", className)}
    />
  );
}

export function Logo({ className, subtitle = true }: { className?: string; subtitle?: boolean }) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      <LogoMark className="h-9 w-9" />
      <div className="leading-none">
        <p className="text-[15px] font-semibold tracking-[0.14em] text-white">VERIION</p>
        {subtitle && <p className="mt-1 text-[10px] font-medium uppercase tracking-[0.22em] text-sidebar-muted">Operating System</p>}
      </div>
    </div>
  );
}
