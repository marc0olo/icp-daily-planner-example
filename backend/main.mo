import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Bool "mo:base/Bool";
import Cycles "mo:base/ExperimentalCycles";
import HashMap "mo:base/HashMap";
import Int "mo:base/Int";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Result "mo:base/Result";

import Helpers "Helpers";
import Serde "Serde";
import Types "Types";

actor {

  // create a stable variable to store the data
  stable var dayDataEntries : [(Text, Types.DayData)] = [];

  // create a HashMap to store the data
  var dayData = HashMap.HashMap<Text, Types.DayData>(0, Text.equal, Text.hash);

  // initialize the HashMap with the stable data
  dayData := HashMap.fromIter<Text, Types.DayData>(dayDataEntries.vals(), 0, Text.equal, Text.hash);

  // query function to get data for a specific date
  public query func getDayData(date : Text) : async ?Types.DayData {
    dayData.get(date);
  };

  // query function to get data for an entire month
  public query func getMonthData(year : Nat, month : Nat) : async [(Text, Types.DayData)] {
    let monthPrefix = Text.concat(Int.toText(year), "-" # Int.toText(month) # "-");
    Iter.toArray(
      Iter.filter(
        dayData.entries(),
        func((k, _) : (Text, Types.DayData)) : Bool {
          Text.startsWith(k, #text monthPrefix);
        },
      )
    );
  };

  // update function to add a note
  public func addNote(date : Text, content : Text) : async Types.AddNoteResult {
    let currentData = switch (dayData.get(date)) {
      case null { { notes = []; onThisDay = null } };
      case (?data) { data };
    };

    let newNote : Types.Note = {
      id = Array.size(currentData.notes);
      content = content;
      isCompleted = false;
    };

    let updatedNotes = Array.append(currentData.notes, [newNote]);
    let updatedData : Types.DayData = {
      notes = updatedNotes;
      onThisDay = currentData.onThisDay;
    };
    dayData.put(date, updatedData);
    #ok("Added note for date: " # date);
    // currently there is no error case in the result
    // code could be extended to disallow adding notes for past days
  };

  // update function to complete a note
  public func completeNote(date : Text, noteId : Nat) : async () {
    switch (dayData.get(date)) {
      case null { /* Do nothing if no data for this date */ };
      case (?data) {
        let updatedNotes = Array.map<Types.Note, Types.Note>(
          data.notes,
          func(note) {
            if (note.id == noteId) {
              return {
                id = note.id;
                content = note.content;
                isCompleted = true;
              };
            } else {
              return note;
            };
          },
        );
        let updatedData : Types.DayData = {
          notes = updatedNotes;
          onThisDay = data.onThisDay;
        };
        dayData.put(date, updatedData);
      };
    };
  };

  // update function to fetch and store "On This Day" data via HTTPS outcall
  public func fetchAndStoreOnThisDay(date : Text) : async Result.Result<Text, Text> {
    let currentData : Types.DayData = switch (dayData.get(date)) {
      case null { { notes = []; onThisDay = null } };
      case (?data) { data };
    };

    // perform https outcall only if needed
    if (currentData.onThisDay == null) {
      let parts = Iter.toArray(Text.split(date, #char '-'));
      let month = parts[1];
      let day = parts[2];
      // define the transform context
      let transform_context : Types.TransformContext = {
        function = transformResponse;
        context = Blob.fromArray([]);
      };
      // prepare the https request
      let http_request : Types.HttpRequestArgs = {
        // API must support IPv6
        url = "https://api.wikimedia.org/feed/v1/wikipedia/en/onthisday/selected/" # month # "/" # day;
        // if not set, the https outcall is expensive and the max value of 2045952 is used to calculate the costs
        max_response_bytes = null;
        headers = [];
        // optional for request
        body = null;
        method = #get;
        // optional, but in our case we want to transform the response
        transform = ?transform_context;
      };

      // adding cycles to cover the costs of the https outcall
      // see https outcall cost calculator: https://7joko-hiaaa-aaaal-ajz7a-cai.icp0.io
      Cycles.add<system>(20_949_972_000);

      // init actor of the ic management canister
      // see https://internetcomputer.org/docs/current/references/ic-interface-spec#ic-management-canister
      let ic : Types.IC = actor ("aaaaa-aa");
      // execute the https outcall
      let httpResponse : Types.HttpResponsePayload = await ic.http_request(http_request);
      let responseBody : Blob = Blob.fromArray(httpResponse.body);
      let decodedResult : Types.HttpsOutcallResult = switch (Serde.deserializeOnThisDay(responseBody)) {
        case (null) { #err("could not deserialize transformed response.") };
        case (?y) { #ok(y) };
      };
      switch (decodedResult) {
        case (#ok(otd)) {
          let updatedData : Types.DayData = {
            notes = currentData.notes;
            onThisDay = ?otd;
          };
          dayData.put(date, updatedData); // store the updated data
          #ok("data successfully obtained and stored for date: " # date);
        };
        case (#err(msg)) { #err(msg) };
      };
    } else {
      #err("data already stored for date: " # date);
    };
  };

  public query func transformResponse(raw : Types.TransformArgs) : async Types.HttpResponsePayload {
    let response_body : Blob = Blob.fromArray(raw.response.body);
    let decoded_text : Text = switch (Text.decodeUtf8(response_body)) {
      case (null) { "No value returned" };
      case (?y) { y };
    };
    let transformed : Types.HttpResponsePayload = {
      status = raw.response.status;
      body = Blob.toArray(Serde.serializeOnThisDay(Helpers.extractOnThisDayValues(decoded_text)));
      headers = raw.response.headers;
    };
    transformed;
  };

  // Pre-upgrade hook to store the data
  system func preupgrade() {
    dayDataEntries := Iter.toArray(dayData.entries());
  };

  // Post-upgrade hook to restore the data
  system func postupgrade() {
    dayData := HashMap.fromIter<Text, Types.DayData>(dayDataEntries.vals(), 0, Text.equal, Text.hash);
  };
};
