"use client";

import { useEffect, useMemo, useState } from "react";
import {
  guidanceForDecision,
  priorsForSuggestion,
  suggestDecision,
} from "@/domain/decisionSuggester";
import { earlierPhases, previousPhase } from "@/domain/types";
import type { RehabPhase, Response24h, SessionDecision, TrainingSession } from "@/domain/types";
import { sessionToSnapshot } from "@/domain/types";
import { GhostButton, PrimaryButton, Segmented, Sheet } from "./ui";

export function ResolveSheet({
  open,
  onClose,
  session,
  allSessions,
  currentPhase,
  onResolve,
}: {
  open: boolean;
  onClose: () => void;
  session: TrainingSession | null;
  allSessions: TrainingSession[];
  currentPhase: RehabPhase;
  onResolve: (args: {
    id: string;
    response: Response24h;
    decision: SessionDecision;
    nextPhase?: RehabPhase | null;
  }) => Promise<void>;
}) {
  const [response, setResponse] = useState<Response24h>("same");
  const [decision, setDecision] = useState<SessionDecision>("stay");
  const [confirmHard, setConfirmHard] = useState(false);
  const [nextPhase, setNextPhase] = useState<RehabPhase | "none">("none");

  const suggested = useMemo(() => {
    if (!session) return null;
    const priors = priorsForSuggestion(
      sessionToSnapshot(session),
      allSessions.map(sessionToSnapshot),
    );
    return suggestDecision(response, priors);
  }, [session, allSessions, response]);

  useEffect(() => {
    if (!open || !session) return;
    if (session.response24h === "pending") {
      setResponse("same");
      const priors = priorsForSuggestion(
        sessionToSnapshot(session),
        allSessions.map(sessionToSnapshot),
      );
      setDecision(suggestDecision("same", priors) ?? "stay");
      setConfirmHard(false);
      setNextPhase("none");
    } else {
      setResponse(session.response24h === "notApplicable" ? "same" : session.response24h);
      setDecision(session.decision ?? "stay");
    }
  }, [open, session, allSessions]);

  useEffect(() => {
    if (suggested) setDecision(suggested);
  }, [suggested]);

  if (!session) return null;

  const guidance = guidanceForDecision(decision);
  const saveClinical = async () => {
    if (decision === "hardDrop") {
      setConfirmHard(true);
      setNextPhase(previousPhase(currentPhase) ?? "none");
      return;
    }
    await onResolve({ id: session.id, response, decision });
    onClose();
  };

  return (
    <Sheet
      open={open}
      title="Resolve 24h"
      onClose={onClose}
      footer={
        confirmHard ? (
          <div className="flex flex-col gap-2">
            <PrimaryButton
              onClick={async () => {
                await onResolve({
                  id: session.id,
                  response,
                  decision: "hardDrop",
                  nextPhase: nextPhase === "none" ? null : nextPhase,
                });
                onClose();
              }}
            >
              Confirm hard drop
            </PrimaryButton>
            <GhostButton onClick={() => setConfirmHard(false)}>Back</GhostButton>
          </div>
        ) : (
          <div className="flex flex-col gap-2">
            <PrimaryButton onClick={saveClinical}>Save</PrimaryButton>
            <GhostButton
              onClick={async () => {
                await onResolve({
                  id: session.id,
                  response: "notApplicable",
                  decision: "rest",
                });
                onClose();
              }}
            >
              Close as Rest
            </GhostButton>
          </div>
        )
      }
    >
      <div className="flex flex-col gap-5">
        <div>
          <p className="text-sm text-ink">{session.whatIDid}</p>
          <p className="mt-1 text-xs text-muted">
            {session.date} · after {session.painAfter}/10
          </p>
        </div>
        {confirmHard ? (
          <>
            <p className="text-sm text-muted">
              Hard drop means consider an earlier phase. The app will not change phase unless you pick one.
            </p>
            <Segmented<RehabPhase | "none">
              ariaLabel="Also set phase"
              value={nextPhase}
              onChange={setNextPhase}
              options={[
                { value: "none", label: "Keep phase" },
                ...earlierPhases(currentPhase).map((p) => ({ value: p, label: p })),
              ]}
            />
          </>
        ) : (
          <>
            <div>
              <p className="mb-2 text-sm font-semibold">How is the tendon this morning?</p>
              <Segmented<Response24h>
                ariaLabel="24h response"
                value={response}
                onChange={setResponse}
                options={[
                  { value: "better", label: "Better" },
                  { value: "same", label: "Same" },
                  { value: "worse", label: "Worse" },
                ]}
              />
            </div>
            <div>
              <p className="mb-2 text-sm font-semibold">Decision</p>
              <Segmented<SessionDecision>
                ariaLabel="Decision"
                value={decision}
                onChange={setDecision}
                options={[
                  { value: "stay", label: "Stay" },
                  { value: "softCut", label: "Soft" },
                  { value: "progress", label: "Prog" },
                  { value: "hardDrop", label: "Hard" },
                ]}
              />
              {suggested && suggested !== decision ? (
                <p className="mt-2 text-xs text-gold">Suggested: {suggested}</p>
              ) : null}
              {guidance ? <p className="mt-2 text-sm text-muted">{guidance}</p> : null}
            </div>
          </>
        )}
      </div>
    </Sheet>
  );
}
