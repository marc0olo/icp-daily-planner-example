import Bool "mo:base/Bool";
import Char "mo:base/Char";
import Nat32 "mo:base/Nat32";

import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Time "mo:base/Time";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

actor {
  // Define types
  type Note = {
    id: Nat;
    content: Text;
    isCompleted: Bool;
  };

  type OnThisDay = {
    title: Text;
    year: Int;
    wikiLink: Text;
  };

  type DayData = {
    notes: [Note];
    onThisDay: ?OnThisDay;
  };

  // Create a stable variable to store the data
  stable var dayDataEntries : [(Text, DayData)] = [];

  // Create a HashMap to store the data
  var dayData = HashMap.HashMap<Text, DayData>(0, Text.equal, Text.hash);

  // Initialize the HashMap with the stable data
  dayData := HashMap.fromIter<Text, DayData>(dayDataEntries.vals(), 0, Text.equal, Text.hash);

  // Function to add a note
  public func addNote(date: Text, content: Text) : async () {
    let currentTimestamp = Time.now();
    let currentDate = Int.abs(currentTimestamp / (24 * 60 * 60 * 1000_000_000));
    let inputDate = textToDate(date);

    if (inputDate >= currentDate) {
      let currentData = switch (dayData.get(date)) {
        case null { { notes = []; onThisDay = null; } };
        case (?data) { data };
      };
      
      let newNote : Note = {
        id = Array.size(currentData.notes);
        content = content;
        isCompleted = false;
      };
      
      let updatedNotes = Array.append(currentData.notes, [newNote]);
      let updatedData : DayData = {
        notes = updatedNotes;
        onThisDay = currentData.onThisDay;
      };
      
      dayData.put(date, updatedData);
    } else {
      Debug.print("Cannot add notes to past dates");
    };
  };

  // Function to complete a note
  public func completeNote(date: Text, noteId: Nat) : async () {
    switch (dayData.get(date)) {
      case null { /* Do nothing if no data for this date */ };
      case (?data) {
        let updatedNotes = Array.map<Note, Note>(data.notes, func (note) {
          if (note.id == noteId) {
            return { id = note.id; content = note.content; isCompleted = true; };
          } else {
            return note;
          };
        });
        let updatedData : DayData = {
          notes = updatedNotes;
          onThisDay = data.onThisDay;
        };
        dayData.put(date, updatedData);
      };
    };
  };

  // Function to get data for a specific date
  public query func getDayData(date: Text) : async ?DayData {
    dayData.get(date)
  };

  // Function to store "On This Day" data
  public func storeOnThisDay(date: Text, title: Text, year: Int, wikiLink: Text) : async () {
    let currentData = switch (dayData.get(date)) {
      case null { { notes = []; onThisDay = null; } };
      case (?data) { data };
    };
    
    let updatedData : DayData = {
      notes = currentData.notes;
      onThisDay = ?{ title = title; year = year; wikiLink = wikiLink; };
    };
    
    dayData.put(date, updatedData);
  };

  // New function to get data for an entire month
  public query func getMonthData(year: Nat, month: Nat) : async [(Text, DayData)] {
    let monthPrefix = Text.concat(Int.toText(year), "-" # Int.toText(month) # "-");
    Iter.toArray(Iter.filter(dayData.entries(), func ((k, _) : (Text, DayData)) : Bool {
      Text.startsWith(k, #text monthPrefix)
    }))
  };

  // Helper function to convert date string to timestamp
  private func textToDate(dateStr: Text) : Int {
    let parts = Iter.toArray(Text.split(dateStr, #char '-'));
    if (parts.size() == 3) {
      let year = textToNat(parts[0]);
      let month = textToNat(parts[1]);
      let day = textToNat(parts[2]);
      // Simplified date to days since epoch calculation
      return (year * 365 + month * 30 + day);
    };
    return 0;
  };

  // Helper function to convert text to Nat
  private func textToNat(t : Text) : Nat {
    var n : Nat = 0;
    for (c in t.chars()) {
      let charToNat = Nat32.toNat(Char.toNat32(c) - 48);
      if (charToNat >= 0 and charToNat <= 9) {
        n := n * 10 + charToNat;
      };
    };
    n
  };

  // Pre-upgrade hook to store the data
  system func preupgrade() {
    dayDataEntries := Iter.toArray(dayData.entries());
  };

  // Post-upgrade hook to restore the data
  system func postupgrade() {
    dayData := HashMap.fromIter<Text, DayData>(dayDataEntries.vals(), 0, Text.equal, Text.hash);
  };
}
