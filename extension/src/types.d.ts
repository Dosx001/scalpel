type Message =
  | {
      type: "ping";
    }
  | {
      type: "window";
      payload: {
        url: string;
        private?: boolean;
      };
    };
