import "server-only";
import nodemailer, { type Transporter } from "nodemailer";
import { NOTIFICATION_CATEGORIES, type NotificationCategory } from "@/lib/notifications";

let transport: Transporter | null = null;

export function mailerConfigured() {
  return !!process.env.SMTP_HOST && !!process.env.SMTP_FROM;
}

function getTransport() {
  if (!transport) {
    const port = Number(process.env.SMTP_PORT || 587);
    transport = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port,
      secure: process.env.SMTP_SECURE ? process.env.SMTP_SECURE === "true" : port === 465,
      auth: process.env.SMTP_USER ? { user: process.env.SMTP_USER, pass: process.env.SMTP_PASSWORD } : undefined,
      pool: true,
      maxConnections: 3,
    });
  }
  return transport;
}

export type MailItem = { title: string; body: string | null; link: string | null; category: NotificationCategory; created_at: string };

const esc = (s: string) => s.replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]!);
const siteUrl = () => (process.env.NEXT_PUBLIC_SITE_URL || "http://localhost:3000").replace(/\/+$/, "");
const absolute = (link: string | null) => (!link ? siteUrl() : /^https?:\/\//.test(link) ? link : `${siteUrl()}${link.startsWith("/") ? "" : "/"}${link}`);
const timeFr = (d: string) =>
  new Intl.DateTimeFormat("fr-FR", { timeZone: process.env.NEXT_PUBLIC_TIMEZONE || "Africa/Porto-Novo", day: "numeric", month: "short", hour: "2-digit", minute: "2-digit" }).format(new Date(d));

/** Compose l'e-mail (HTML compatible clients de messagerie + version texte). */
export function renderNotificationEmail(firstName: string, items: MailItem[], digest: boolean) {
  const n = items.length;
  const subject = digest
    ? `Votre résumé VERIION : ${n} notification${n > 1 ? "s" : ""}`
    : n === 1 ? items[0].title : `${n} nouvelles notifications sur VERIION OS`;
  const intro = digest
    ? `Voici ce qui vous attend sur VERIION OS depuis votre dernier résumé.`
    : n === 1 ? `Vous avez une nouvelle notification sur VERIION OS.` : `Vous avez ${n} nouvelles notifications sur VERIION OS.`;

  const groups = NOTIFICATION_CATEGORIES.map((c) => ({ c, list: items.filter((i) => i.category === c.key) })).filter((g) => g.list.length);
  const rows = groups.map(({ c, list }) => `
    <tr><td style="padding:22px 0 6px;font:600 11px/1.4 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:.08em;text-transform:uppercase;color:#6b7280">${esc(c.label)}</td></tr>
    ${list.map((i) => `
    <tr><td style="padding:0 0 10px">
      <a href="${esc(absolute(i.link))}" style="display:block;text-decoration:none;border:1px solid #e5e7eb;border-radius:12px;padding:14px 16px;background:#ffffff">
        <span style="display:block;font:600 15px/1.4 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0b1020">${esc(i.title)}</span>
        ${i.body ? `<span style="display:block;margin-top:4px;font:14px/1.5 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#4b5563">${esc(i.body)}</span>` : ""}
        <span style="display:block;margin-top:8px;font:12px/1.4 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#9ca3af">${esc(timeFr(i.created_at))} · <span style="color:#4f46e5">Ouvrir</span></span>
      </a>
    </td></tr>`).join("")}`).join("");

  const html = `<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(subject)}</title></head>
<body style="margin:0;padding:0;background:#f4f5fb">
  <span style="display:none;max-height:0;overflow:hidden">${esc(items[0]?.title ?? "")}</span>
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f4f5fb"><tr><td align="center" style="padding:32px 16px">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px">
      <tr><td style="padding:0 0 20px">
        <table role="presentation" cellpadding="0" cellspacing="0"><tr>
          <td style="width:36px;height:36px;border-radius:10px;background:#4f46e5;background-image:linear-gradient(135deg,#818cf8,#6366f1 55%,#a855f7);text-align:center;font:700 18px/36px Arial,sans-serif;color:#fff">V</td>
          <td style="padding-left:10px;font:700 15px/1.2 -apple-system,Segoe UI,Roboto,Arial,sans-serif;letter-spacing:.12em;color:#0b1020">VERIION<br><span style="font-weight:500;font-size:10px;letter-spacing:.2em;color:#6b7280">OPERATING SYSTEM</span></td>
        </tr></table>
      </td></tr>
      <tr><td style="background:#ffffff;border-radius:16px;padding:28px 28px 18px;border:1px solid #eceef5">
        <p style="margin:0 0 6px;font:600 20px/1.3 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#0b1020">Bonjour ${esc(firstName)},</p>
        <p style="margin:0;font:15px/1.6 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#4b5563">${esc(intro)}</p>
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">${rows}</table>
        <table role="presentation" cellpadding="0" cellspacing="0" style="margin:14px 0 8px"><tr><td style="border-radius:10px;background:#4f46e5">
          <a href="${esc(siteUrl())}" style="display:inline-block;padding:11px 20px;font:600 14px/1 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#ffffff;text-decoration:none">Ouvrir VERIION OS</a>
        </td></tr></table>
      </td></tr>
      <tr><td style="padding:18px 8px;font:12px/1.6 -apple-system,Segoe UI,Roboto,Arial,sans-serif;color:#9ca3af;text-align:center">
        Vous recevez cet e-mail car vous avez des notifications non lues sur VERIION OS.<br>
        <a href="${esc(siteUrl())}/parametres?onglet=notifications" style="color:#6b7280">Gérer mes préférences de notification</a> · Usage interne et confidentiel
      </td></tr>
    </table>
  </td></tr></table>
</body></html>`;

  const text = [
    `Bonjour ${firstName},`, "", intro, "",
    ...groups.flatMap(({ c, list }) => [c.label.toUpperCase(), ...list.map((i) => `• ${i.title}${i.body ? ` — ${i.body}` : ""}\n  ${absolute(i.link)}`), ""]),
    `Ouvrir VERIION OS : ${siteUrl()}`,
    `Gérer mes préférences : ${siteUrl()}/parametres?onglet=notifications`,
  ].join("\n");

  return { subject, html, text };
}

export async function sendMail(to: string, content: { subject: string; html: string; text: string }) {
  await getTransport().sendMail({
    from: process.env.SMTP_FROM,
    to,
    subject: content.subject,
    html: content.html,
    text: content.text,
    headers: { "Auto-Submitted": "auto-generated", "X-Auto-Response-Suppress": "All" },
  });
}
