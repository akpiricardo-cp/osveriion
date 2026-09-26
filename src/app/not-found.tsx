import Link from "next/link";
import { LogoMark } from "@/components/logo";

export default function NotFound() {
  return (
    <div className="grid min-h-screen place-items-center bg-bg px-6 text-center">
      <div>
        <LogoMark className="mx-auto h-12 w-12" />
        <p className="mt-6 text-sm font-medium text-primary">Erreur 404</p>
        <h1 className="mt-2 text-2xl font-semibold tracking-tight text-fg">Page introuvable</h1>
        <p className="mt-2 text-sm text-muted">Cette page n&apos;existe pas ou vous n&apos;y avez pas accès.</p>
        <Link href="/" className="mt-6 inline-block rounded-lg bg-primary px-4 py-2 text-sm font-medium text-white hover:bg-primary-hover">Retour à l&apos;accueil</Link>
      </div>
    </div>
  );
}
