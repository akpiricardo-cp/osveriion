import { Select } from "@/components/ui/input";
import type { ProfileLite } from "@/lib/types";

export function PersonSelect({
  people, name, defaultValue, placeholder = "— Non assigné —", required, id,
}: { people: ProfileLite[]; name: string; defaultValue?: string | null; placeholder?: string; required?: boolean; id?: string }) {
  return (
    <Select name={name} id={id ?? name} defaultValue={defaultValue ?? ""} required={required}>
      <option value="">{placeholder}</option>
      {people.map((p) => (
        <option key={p.id} value={p.id}>
          {p.full_name}{p.job_title ? ` — ${p.job_title}` : ""}
        </option>
      ))}
    </Select>
  );
}

export function UnitSelect({
  units, name, defaultValue, placeholder = "— Aucune —", required, id,
}: { units: { id: string; label: string }[]; name: string; defaultValue?: string | null; placeholder?: string; required?: boolean; id?: string }) {
  return (
    <Select name={name} id={id ?? name} defaultValue={defaultValue ?? ""} required={required}>
      <option value="">{placeholder}</option>
      {units.map((u) => (
        <option key={u.id} value={u.id}>{u.label}</option>
      ))}
    </Select>
  );
}
