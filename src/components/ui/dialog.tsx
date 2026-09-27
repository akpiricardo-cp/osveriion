"use client";

import * as React from "react";
import * as D from "@radix-ui/react-dialog";
import { X } from "lucide-react";
import { cn } from "@/lib/utils";

export const Dialog = D.Root;
export const DialogTrigger = D.Trigger;
export const DialogClose = D.Close;

export function DialogContent({
  title, description, children, className, size = "md",
}: {
  title: React.ReactNode;
  description?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  size?: "sm" | "md" | "lg" | "xl";
}) {
  const w = { sm: "max-w-md", md: "max-w-lg", lg: "max-w-2xl", xl: "max-w-4xl" }[size];
  return (
    <D.Portal>
      <D.Overlay className="fixed inset-0 z-50 bg-black/40 backdrop-blur-[2px] data-[state=open]:animate-in data-[state=open]:fade-in-0" />
      <D.Content
        className={cn(
          // Telephone : feuille ancree en bas, a portee du pouce. Ecran large : fenetre centree.
          "fixed inset-x-0 bottom-0 z-50 flex max-h-[92vh] w-full flex-col rounded-t-2xl border border-border bg-surface shadow-2xl outline-none",
          "data-[state=open]:animate-in data-[state=open]:slide-in-from-bottom data-[state=open]:fade-in-0",
          "sm:inset-x-auto sm:bottom-auto sm:left-1/2 sm:top-1/2 sm:max-h-[90vh] sm:w-[calc(100vw-2rem)] sm:-translate-x-1/2 sm:-translate-y-1/2 sm:rounded-2xl",
          "sm:data-[state=open]:zoom-in-95 sm:data-[state=open]:slide-in-from-bottom-0",
          w,
          className,
        )}
      >
        <div className="flex items-start justify-between gap-4 border-b border-border px-5 py-4 sm:px-6">
          <div>
            <D.Title className="text-base font-semibold tracking-tight text-fg">{title}</D.Title>
            {description ? (
              <D.Description className="mt-1 text-[13px] text-muted">{description}</D.Description>
            ) : (
              <D.Description className="sr-only">{typeof title === "string" ? title : "Boîte de dialogue"}</D.Description>
            )}
          </div>
          <D.Close className="rounded-md p-1 text-subtle transition hover:bg-surface-2 hover:text-fg" aria-label="Fermer">
            <X className="h-4 w-4" />
          </D.Close>
        </div>
        <div className="overflow-y-auto px-5 py-5 pb-safe sm:px-6">{children}</div>
      </D.Content>
    </D.Portal>
  );
}

export function Sheet({
  open, onOpenChange, title, description, children, width = "max-w-xl",
}: {
  open: boolean;
  onOpenChange: (o: boolean) => void;
  title: React.ReactNode;
  description?: React.ReactNode;
  children: React.ReactNode;
  width?: string;
}) {
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="fixed inset-0 z-50 bg-black/30 backdrop-blur-[1px] data-[state=open]:animate-in data-[state=open]:fade-in-0" />
        <D.Content
          className={cn(
            "fixed inset-y-0 right-0 z-50 flex w-full flex-col border-l border-border bg-surface shadow-2xl outline-none",
            "data-[state=open]:animate-in data-[state=open]:slide-in-from-right",
            width,
          )}
        >
          <div className="flex items-start justify-between gap-4 border-b border-border px-5 pt-safe py-4 sm:px-6">
            <div className="min-w-0">
              <D.Title className="truncate text-base font-semibold tracking-tight text-fg">{title}</D.Title>
              <D.Description className={description ? "mt-1 text-[13px] text-muted" : "sr-only"}>
                {description ?? "Panneau latéral"}
              </D.Description>
            </div>
            <D.Close className="rounded-md p-1 text-subtle transition hover:bg-surface-2 hover:text-fg" aria-label="Fermer">
              <X className="h-4 w-4" />
            </D.Close>
          </div>
          <div className="flex-1 overflow-y-auto pb-safe">{children}</div>
        </D.Content>
      </D.Portal>
    </D.Root>
  );
}
