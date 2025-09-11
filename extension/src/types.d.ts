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
      type: "url";
      id: number;
      url: string;
    }
  | {
      type: "window";
      url: string;
      private?: boolean;
    };
