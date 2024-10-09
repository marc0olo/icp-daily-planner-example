import Result "mo:base/Result";

module Types {

    // general
    public type Note = {
        id : Nat;
        content : Text;
        isCompleted : Bool;
    };

    public type OnThisDay = {
        title : Text;
        year : Text;
        wikiLink : Text;
    };

    public type DayData = {
        notes : [Note];
        onThisDay : ?OnThisDay;
    };

    public type AddNoteResult = Result.Result<Text, Text>;

    // https outcall
    public type HttpsOutcallResult = Result.Result<OnThisDay, Text>;

    public type HttpRequestArgs = {
        url : Text;
        max_response_bytes : ?Nat64;
        headers : [HttpHeader];
        body : ?[Nat8];
        method : HttpMethod;
        transform : ?TransformContext;
    };

    public type HttpHeader = {
        name : Text;
        value : Text;
    };

    public type HttpMethod = {
        #get;
        #post;
        #head;
    };

    public type HttpResponsePayload = {
        status : Nat;
        headers : [HttpHeader];
        body : [Nat8];
    };

    public type TransformContext = {
        function : shared query TransformArgs -> async HttpResponsePayload;
        context : Blob;
    };

    public type TransformArgs = {
        response : HttpResponsePayload;
        context : Blob;
    };

    public type IC = actor {
        http_request : HttpRequestArgs -> async HttpResponsePayload;
    };
};
