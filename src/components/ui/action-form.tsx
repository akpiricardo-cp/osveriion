"use client";

import * as React from "react";
import { useActionState, useEffect, useRef } from "react";
import { useFormStatus } from "react-dom";
import { toast } from "sonner";
import { Button } from "./button";
import type { ActionResult } from "@/lib/types";

export type FormAction = (prev: ActionResult | null, formData: FormData) => Promise<ActionResult>;

export function SubmitButton({
  children, variant = "primary", className,
}: { children: React.ReactNode; variant?: "primary" | "danger" | "success" | "outline"; className?: string }) {
  const { pending } = useFormStatus();
  return (
    <Button type="submit" loading={pending} variant={variant} className={className}>
      {children}
    </Button>
  );
}

/**
 * Formulaire relié à une Server Action : gère l'état, les toasts et la fermeture.
 */
export function ActionForm({
  action, children, submitLabel = "Enregistrer", onSuccess, className, footer = true, resetOnSuccess = true,
  submitVariant, secondary,
}: {
  action: FormAction;
  children: React.ReactNode;
  submitLabel?: string;
  onSuccess?: (res: ActionResult) => void;
  className?: string;
  footer?: boolean;
  resetOnSuccess?: boolean;
  submitVariant?: "primary" | "danger" | "success";
  secondary?: React.ReactNode;
}) {
  const [state, formAction] = useActionState(action, null);
  const ref = useRef<HTMLFormElement>(null);
  const onSuccessRef = useRef(onSuccess);
  onSuccessRef.current = onSuccess;

  useEffect(() => {
    if (!state) return;
    if (state.ok) {
      if (state.message) toast.success(state.message);
      if (resetOnSuccess) ref.current?.reset();
      onSuccessRef.current?.(state);
    } else {
      toast.error(state.error);
    }
  }, [state, resetOnSuccess]);

  return (
    <form ref={ref} action={formAction} className={className ?? "space-y-4"}>
      {children}
      {footer && (
        <div className="flex items-center justify-end gap-2 pt-2">
          {secondary}
          <SubmitButton variant={submitVariant}>{submitLabel}</SubmitButton>
        </div>
      )}
    </form>
  );
}
