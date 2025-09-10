type Payload =
  | {
      type: "ping";
    }
  | {
      type: "click" | "text";
      id: number;
      query: string;
    }
  | {
      type: "window";
      url: string;
      private?: boolean;
    };
