import { NextResponse, type NextRequest } from "next/server";
import { createClient } from "@/lib/supabase/server";

const BUCKETS = new Set(["documents", "doc-assets", "chat"]);

/**
 * Sert un fichier du stockage Supabase avec la session de l'utilisateur :
 * les politiques RLS du stockage décident de l'accès (aucune URL publique).
 */
export async function GET(request: NextRequest, { params }: { params: Promise<{ bucket: string; path: string[] }> }) {
  const { bucket, path } = await params;
  if (!BUCKETS.has(bucket)) return new NextResponse("Not found", { status: 404 });
  const key = path.map(decodeURIComponent).join("/");
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return new NextResponse("Unauthorized", { status: 401 });

  const { data, error } = await supabase.storage.from(bucket).download(key);
  if (error || !data) return new NextResponse("Fichier introuvable ou accès refusé", { status: 404 });

  const name = request.nextUrl.searchParams.get("nom") ?? key.split("/").pop() ?? "fichier";
  const download = request.nextUrl.searchParams.has("telecharger");
  const type = data.type || "application/octet-stream";
  // Les types potentiellement actifs sont toujours téléchargés, jamais affichés.
  const risky = /html|javascript|xml|svg/.test(type);
  return new NextResponse(data, {
    headers: {
      "Content-Type": risky ? "application/octet-stream" : type,
      "Content-Length": String(data.size),
      "Content-Disposition": `${download || risky ? "attachment" : "inline"}; filename*=UTF-8''${encodeURIComponent(name)}`,
      "Cache-Control": "private, max-age=600",
      "X-Content-Type-Options": "nosniff",
    },
  });
}
