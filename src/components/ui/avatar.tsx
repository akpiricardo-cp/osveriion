import * as React from "react";
import { cn, initials } from "@/lib/utils";

const palette = [
  "from-indigo-500 to-violet-500", "from-sky-500 to-cyan-500", "from-emerald-500 to-teal-500",
  "from-amber-500 to-orange-500", "from-rose-500 to-pink-500", "from-fuchsia-500 to-purple-500",
];

function hash(s: string) {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) | 0;
  return Math.abs(h);
}

const sizes = { xs: "h-6 w-6 text-[10px]", sm: "h-8 w-8 text-xs", md: "h-10 w-10 text-sm", lg: "h-14 w-14 text-lg", xl: "h-20 w-20 text-2xl" };

export function Avatar({
  name, src, size = "sm", className, ring,
}: { name?: string | null; src?: string | null; size?: keyof typeof sizes; className?: string; ring?: boolean }) {
  const cls = cn(
    "relative inline-grid shrink-0 place-items-center overflow-hidden rounded-full font-semibold text-white",
    sizes[size],
    ring && "ring-2 ring-surface",
    className,
  );
  if (src) {
    // eslint-disable-next-line @next/next/no-img-element
    return <img src={src} alt={name ?? ""} className={cn(cls, "object-cover")} />;
  }
  return (
    <span className={cn(cls, "bg-gradient-to-br", palette[hash(name ?? "?") % palette.length])} aria-label={name ?? ""}>
      {initials(name)}
    </span>
  );
}

export function AvatarStack({ people, max = 4 }: { people: { full_name: string; avatar_url?: string | null }[]; max?: number }) {
  const shown = people.slice(0, max);
  const rest = people.length - shown.length;
  return (
    <div className="flex -space-x-2">
      {shown.map((p, i) => (
        <Avatar key={i} name={p.full_name} src={p.avatar_url} size="xs" ring />
      ))}
      {rest > 0 && (
        <span className="grid h-6 w-6 place-items-center rounded-full bg-surface-3 text-[10px] font-medium text-muted ring-2 ring-surface">
          +{rest}
        </span>
      )}
    </div>
  );
}
