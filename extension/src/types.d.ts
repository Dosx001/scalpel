type Message =
  | {
      type: "ping";
    }
  | {
      type: "click" | "text";
      payload: {
        id: number;
        query: string;
      };
    }
  | {
      type: "window";
      payload: {
        url: string;
        private?: boolean;
      };
    };
