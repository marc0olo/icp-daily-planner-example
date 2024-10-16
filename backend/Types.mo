import Result "mo:base/Result";

import IC "ic:aaaaa-aa";

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

    public type TransformArgs = {
        response : IC.http_request_result;
        context : Blob;
    };
};
