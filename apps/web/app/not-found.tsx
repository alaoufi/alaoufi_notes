import Link from "next/link";

export default function NotFound() {
  return (
    <html lang="ar" dir="rtl">
      <body
        style={{
          fontFamily: "system-ui, sans-serif",
          minHeight: "100dvh",
          display: "grid",
          placeItems: "center",
          background: "#f7f9fc",
          color: "#0f172a",
          margin: 0,
        }}
      >
        <div style={{ textAlign: "center" }}>
          <h1 style={{ fontSize: 48, margin: 0 }}>404</h1>
          <p style={{ margin: "8px 0 24px", color: "#52607a" }}>
            الصفحة غير موجودة · Page not found
          </p>
          <Link
            href="/"
            style={{
              display: "inline-block",
              padding: "10px 20px",
              background: "#1f6feb",
              color: "white",
              borderRadius: 8,
              textDecoration: "none",
            }}
          >
            الرئيسية · Home
          </Link>
        </div>
      </body>
    </html>
  );
}
