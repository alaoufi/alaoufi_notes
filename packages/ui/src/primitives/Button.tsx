import * as React from "react";
import { cn } from "../lib/cn";

type Variant = "primary" | "secondary" | "ghost" | "danger" | "outline";
type Size = "sm" | "md" | "lg";

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
  size?: Size;
  loading?: boolean;
  iconStart?: React.ReactNode;
  iconEnd?: React.ReactNode;
  fullWidth?: boolean;
}

const variantClasses: Record<Variant, string> = {
  primary:
    "bg-primary text-primary-contrast hover:bg-primary-hover shadow-sm disabled:opacity-60",
  secondary:
    "bg-surface-muted text-text hover:bg-border disabled:opacity-60",
  ghost:
    "bg-transparent text-text hover:bg-surface-muted disabled:opacity-60",
  outline:
    "bg-transparent text-text border border-border hover:bg-surface-muted disabled:opacity-60",
  danger:
    "bg-danger text-primary-contrast hover:opacity-90 disabled:opacity-60",
};

const sizeClasses: Record<Size, string> = {
  sm: "h-9 px-3 text-sm rounded-md gap-1.5",
  md: "h-11 px-5 text-base rounded-md gap-2",
  lg: "h-13 px-6 text-lg rounded-lg gap-2.5",
};

export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  {
    variant = "primary",
    size = "md",
    loading = false,
    iconStart,
    iconEnd,
    fullWidth,
    className,
    children,
    disabled,
    type = "button",
    ...rest
  },
  ref,
) {
  return (
    <button
      ref={ref}
      type={type}
      disabled={disabled || loading}
      aria-busy={loading || undefined}
      className={cn(
        "inline-flex items-center justify-center font-medium transition-colors duration-base ease-standard",
        "focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-primary/40",
        "disabled:cursor-not-allowed",
        variantClasses[variant],
        sizeClasses[size],
        fullWidth && "w-full",
        className,
      )}
      {...rest}
    >
      {loading ? (
        <span
          aria-hidden
          className="h-4 w-4 animate-spin rounded-full border-2 border-current border-t-transparent"
        />
      ) : (
        iconStart && <span aria-hidden>{iconStart}</span>
      )}
      <span>{children}</span>
      {iconEnd && !loading && <span aria-hidden>{iconEnd}</span>}
    </button>
  );
});
