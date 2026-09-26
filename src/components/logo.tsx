import { cn } from "@/lib/utils";

export function LogoMark({ className }: { className?: string }) {
  return (
    <span
      className={cn("inline-grid h-8 w-8 shrink-0 place-items-center rounded-[28%] bg-gradient-to-br from-indigo-400 via-indigo-500 to-purple-500 shadow-sm shadow-indigo-500/30", className)}
      aria-hidden
    >
      <svg viewBox="0 0 32 32" className="h-full w-full">
        <path d="M8.5 9.5 16 23l7.5-13.5" fill="none" stroke="#fff" strokeWidth="3" strokeLinecap="round" strokeLinejoin="round" />
        <circle cx="16" cy="9.6" r="1.9" fill="#fff" opacity="0.9" />
      </svg>
    </span>
  );
}

export function Logo({ className, subtitle = true }: { className?: string; subtitle?: boolean }) {
  return (
    <div className={cn("flex items-center gap-2.5", className)}>
      <LogoMark />
      <div className="leading-none">
        <p className="text-[15px] font-semibold tracking-[0.14em] text-white">VERIION</p>
        {subtitle && <p className="mt-1 text-[10px] font-medium uppercase tracking-[0.22em] text-sidebar-muted">Operating System</p>}
      </div>
    </div>
  );
}
