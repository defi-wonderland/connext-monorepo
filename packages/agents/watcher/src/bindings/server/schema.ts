import { AdminSchema, NxtpErrorJsonSchema, TAddress } from "@connext/nxtp-utils";
import { Static, Type } from "@sinclair/typebox";

const TransactionResultSchema = Type.Object({
  domain: Type.String(),
  hash: Type.String(),
  error: Type.Any(),
  relevantTransaction: Type.Any(),
});

export const PauseRequestSchema = Type.Intersect([AdminSchema, Type.Object({ reason: Type.String() })]);
export type PauseRequest = Static<typeof PauseRequestSchema>;

export const PauseResponseSchema = Type.Array(
  Type.Intersect([
    TransactionResultSchema,
    Type.Object({
      paused: Type.Boolean(),
    }),
  ]),
);
export type PauseResponse = Static<typeof PauseResponseSchema>;

export const WatcherApiErrorResponseSchema = Type.Object({
  message: Type.String(),
  error: Type.Optional(NxtpErrorJsonSchema),
});
export type WatcherApiErrorResponse = Static<typeof WatcherApiErrorResponseSchema>;

export const ConfigResponseSchema = Type.Object({
  address: TAddress,
});
export type ConfigResponse = Static<typeof ConfigResponseSchema>;

export const SlowRequestSchema = Type.Intersect([AdminSchema, Type.Object({ reason: Type.String() })]);
export type SlowRequest = Static<typeof SlowRequestSchema>;

export const SlowResponseSchema = Type.Intersect([
  TransactionResultSchema,
  Type.Object({
    switched: Type.Boolean(),
  }),
]);
export type SlowResponse = Static<typeof SlowResponseSchema>;
