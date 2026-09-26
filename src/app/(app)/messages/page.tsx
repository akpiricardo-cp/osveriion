import { MessagesSquare } from "lucide-react";

export default function MessagesHome() {
  return (
    <div className="hidden flex-1 flex-col items-center justify-center p-10 text-center md:flex">
      <div className="mb-4 grid h-14 w-14 place-items-center rounded-2xl bg-primary/10 text-primary"><MessagesSquare className="h-7 w-7" /></div>
      <h2 className="text-lg font-semibold text-fg">Messagerie interne</h2>
      <p className="mt-1 max-w-sm text-sm text-muted">
        Échangez en direct, par département ou par projet. Les communications externes restent sur les e-mails professionnels.
      </p>
    </div>
  );
}
