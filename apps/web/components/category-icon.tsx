import {
  Wind,
  Wrench,
  Zap,
  WashingMachine,
  Home,
  Car,
  Sparkles,
  Bug,
  Tag,
  type LucideIcon,
} from "lucide-react";

const map: Record<string, LucideIcon> = {
  Wind,
  Wrench,
  Zap,
  WashingMachine,
  Home,
  Car,
  Sparkles,
  Bug,
};

export function CategoryIcon({
  iconKey,
  className,
}: {
  iconKey: string | null | undefined;
  className?: string;
}) {
  const Icon = (iconKey && map[iconKey]) || Tag;
  return <Icon className={className ?? "h-5 w-5"} aria-hidden />;
}
