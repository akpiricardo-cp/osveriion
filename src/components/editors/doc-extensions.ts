import StarterKit from "@tiptap/starter-kit";
import TextAlign from "@tiptap/extension-text-align";
import Highlight from "@tiptap/extension-highlight";
import Image from "@tiptap/extension-image";
import { TextStyle, Color } from "@tiptap/extension-text-style";
import { TaskItem, TaskList } from "@tiptap/extension-list";
import { TableKit } from "@tiptap/extension-table";
import { CharacterCount, Placeholder } from "@tiptap/extensions";

/**
 * Extensions de l'éditeur de texte (aussi utilisées pour convertir le HTML importé).
 * En co-édition, l'historique d'annulation est fourni par l'extension Collaboration
 * (chacun annule ses propres modifications), d'où `undoRedo: false`.
 */
export function editorExtensions(placeholder = "Commencez à écrire…", opts?: { collab?: boolean }) {
  return [
    StarterKit.configure({
      ...(opts?.collab ? { undoRedo: false as const } : {}),
      heading: { levels: [1, 2, 3] },
      link: { openOnClick: false, autolink: true, HTMLAttributes: { rel: "noopener noreferrer", target: "_blank" } },
    }),
    TextAlign.configure({ types: ["heading", "paragraph"] }),
    Highlight.configure({ multicolor: false }),
    TextStyle,
    Color,
    TaskList,
    TaskItem.configure({ nested: true }),
    TableKit.configure({ table: { resizable: true } }),
    Image.configure({ allowBase64: true }),
    Placeholder.configure({ placeholder }),
    CharacterCount,
  ];
}
