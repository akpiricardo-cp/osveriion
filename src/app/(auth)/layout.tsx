import { Logo } from "@/components/logo";

export default function AuthLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="grid min-h-screen lg:grid-cols-[1.05fr_1fr]">
      <aside className="relative hidden overflow-hidden bg-brand lg:flex lg:flex-col lg:justify-between lg:p-12">
        <div className="bg-grid absolute inset-0 [mask-image:radial-gradient(ellipse_at_top_left,black_30%,transparent_75%)]" />
        <div className="absolute -left-40 -top-40 h-[520px] w-[520px] rounded-full bg-indigo-600/25 blur-[120px]" />
        <div className="absolute -bottom-40 right-0 h-[420px] w-[420px] rounded-full bg-fuchsia-600/20 blur-[120px]" />
        <Logo className="relative" />
        <div className="relative max-w-lg">
          <p className="mb-4 text-xs font-medium uppercase tracking-[0.25em] text-indigo-300/80">Plateforme interne</p>
          <h1 className="text-4xl font-semibold leading-tight tracking-tight text-white">
            Un seul système pour <span className="text-gradient">piloter VERIION</span>.
          </h1>
          <p className="mt-5 text-[15px] leading-relaxed text-slate-400">
            Organisation, communication, projets, clients, finance, RH et indicateurs — réunis derrière une identité
            unique et des droits qui suivent l&apos;organigramme.
          </p>
          <div className="mt-10 grid grid-cols-3 gap-4">
            {[
              ["1", "identité par employé"],
              ["9", "modules intégrés"],
              ["100 %", "des actions tracées"],
            ].map(([v, l]) => (
              <div key={l} className="rounded-xl border border-white/10 bg-white/[0.03] p-4 backdrop-blur">
                <p className="text-2xl font-semibold text-white">{v}</p>
                <p className="mt-1 text-xs text-slate-400">{l}</p>
              </div>
            ))}
          </div>
        </div>
        <p className="relative text-xs text-slate-500">L&apos;écosystème numérique de l&apos;Afrique · Usage interne et confidentiel</p>
      </aside>
      <main className="flex items-center justify-center px-6 py-12">
        <div className="w-full max-w-sm">{children}</div>
      </main>
    </div>
  );
}
