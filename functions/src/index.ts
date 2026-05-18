import { initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

initializeApp();

type UserRole = "superuser" | "owner" | "staff";
type UserStatus = "active" | "suspended";

interface UserDoc {
  role: UserRole;
  tenant_id: string | null;
  branch_id: string | null;
  status: UserStatus;
}

export const onUserWritten = onDocumentWritten(
  "users/{uid}",
  async (event) => {
    const uid = event.params.uid;
    const auth = getAuth();

    // Documento eliminado: limpiar claims para revocar permisos inmediatamente
    if (!event.data?.after.exists) {
      await auth.setCustomUserClaims(uid, {});
      logger.info("claims cleared for deleted user", { uid });
      return;
    }

    const data = event.data.after.data() as UserDoc;
    const { role, tenant_id, branch_id, status } = data;

    await auth.setCustomUserClaims(uid, {
      role,
      tenant_id: tenant_id ?? null,
      branch_id: branch_id ?? null,
    });

    logger.info("claims updated", { uid, role, tenant_id, branch_id });

    // Revocar refresh tokens al suspender para invalidar sesiones activas en < 1 min.
    // Sin esto, el JWT suspendido sigue siendo válido hasta su expiración (1 hora).
    if (status === "suspended") {
      await auth.revokeRefreshTokens(uid);
      logger.info("refresh tokens revoked for suspended user", { uid });
    }
  }
);
