import * as React from "react";
import { cn } from "../lib/cn";

export interface InputProps extends React.InputHTMLAttributes<HTMLInputElement> {
  label?: string;
  hint?: string;
  error?: string;
  iconStart?: React.ReactNode;
  iconEnd?: React.ReactNode;
}

export const Input = React.forwardRef<HTMLInputElement, InputProps>(function Input(
  { label, hint, error, iconStart, iconEnd, className, id, ...rest },
  ref,
) {
  const generatedId = React.useId();
  const inputId = id ?? generatedId;
  const describedById = error ? `${inputId}-error` : hint ? `${inputId}-hint` : undefined;

  return (
    <div className="flex flex-col gap-1.5">
      {label && (
        <label htmlFor={inputId} className="text-sm font-medium text-text">
          {label}
        </label>
      )}
      <div
        className={cn(
          "flex h-11 items-center rounded-md border bg-surface px-3 transition-colors",
          "focus-within:border-primary",
          error ? "border-danger" : "border-border",
        )}
      >
        {iconStart && (
          <span className="me-2 text-text-muted" aria-hidden>
            {iconStart}
          </span>
        )}
        <input
          ref={ref}
          id={inputId}
          aria-invalid={error ? true : undefined}
          aria-describedby={describedById}
          className={cn(
            "h-full w-full bg-transparent text-text placeholder:text-text-muted/70 outline-none",
            className,
          )}
          {...rest}
        />
        {iconEnd && (
          <span className="ms-2 text-text-muted" aria-hidden>
            {iconEnd}
          </span>
        )}
      </div>
      {error ? (
        <p id={`${inputId}-error`} className="text-sm text-danger">
          {error}
        </p>
      ) : hint ? (
        <p id={`${inputId}-hint`} className="text-sm text-text-muted">
          {hint}
        </p>
      ) : null}
    </div>
  );
});
