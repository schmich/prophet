using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Http;
using System.Threading.Tasks;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;

namespace Prophet
{
    class Program
    {
        static async Task Main(string[] args) {
            await Prophet.Run();
        }
    }

    static class Prophet
    {
        public static async Task Run() {
            var content = await Client.GetStringAsync("http://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard");
            var response = JsonConvert.DeserializeObject<Response>(content);

            var matches = response
                .Events
                .SelectMany(ev => ev.Competitions)
                .Where(match => !match.Status.Type.IsCompleted)
                .Select(match => new {
                    Odds = match.Odds.First(),
                    Teams = match.Competitors.Select(competitor => new {
                        Abbreviation = competitor.Team.Abbreviation,
                        Location = competitor.Team.Location,
                        Record = competitor.Record,
                        IsHome = competitor.IsHome,
                        IsAway = competitor.IsAway
                    }).ToArray()
                })
                .Select(match => new {
                    Odds = match.Odds,
                    Teams = match.Teams,
                    Favorite = match.Teams.First(t => t.Abbreviation == match.Odds.Favorite.TeamAbbreviation),
                    Underdog =  match.Teams.First(t => t.Abbreviation != match.Odds.Favorite.TeamAbbreviation)
                })
                .OrderByDescending(match => {
                    int pointsDelta = match.Favorite.Record.Points() - match.Underdog.Record.Points();
                    int homeFieldAdvantage = match.Favorite.IsHome ? 1 : 0;
                    return -match.Odds.Favorite.Spread * 10000 + pointsDelta * 100 + homeFieldAdvantage;
                });

            foreach (var match in matches) {
                var favorite = match.Favorite;
                var underdog = match.Underdog;
                Console.WriteLine($"{favorite.Location.PadLeft(30)} {favorite.Abbreviation.PadLeft(3)} ({favorite.Record})  {match.Odds.Favorite.Spread.ToString().PadLeft(5)}  ({underdog.Record}) {underdog.Abbreviation.PadRight(3)} {underdog.Location}");
            }
        }

        static readonly HttpClient Client = new HttpClient();
    }

    class Response
    {
        [JsonProperty("events")]
        public List<Event> Events = new List<Event>();
    }

    class Event
    {
        [JsonProperty("competitions")]
        public List<Competition> Competitions = new List<Competition>();
    }

    class Competition
    {
        [JsonProperty("competitors")]
        public List<Competitor> Competitors = new List<Competitor>();

        [JsonProperty("odds")]
        public List<Odds> Odds = new List<Odds>();

        [JsonProperty("status")]
        public Status Status;
    }

    class Status
    {
        [JsonProperty("type")]
        public StatusType Type;
    }

    class StatusType
    {
        [JsonProperty("completed")]
        public bool IsCompleted;
    }

    class Record
    {
        public int Wins;
        public int Losses;
        public int Ties;

        public int Points() => Wins * 2 + Ties;
        public override string ToString() => $"{Wins}-{Losses}-{Ties}";
    }

    class RecordsConverter : JsonConverter
    {
        public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer) {
            var records = JObject.ReadFrom(reader);
            var total = records.First(r => (string)r["type"] == "total");

            string record = (string)total["summary"];
            var parts = record.Split('-', 3);

            return new Record {
                Wins = int.Parse(parts[0]),
                Losses = int.Parse(parts[1]),
                Ties = parts.Length < 3 ? 0 : int.Parse(parts[2])
            };
        }

        public override void WriteJson(JsonWriter writer, object value, JsonSerializer serializer) { }
        public override bool CanWrite => false;
        public override bool CanConvert(Type objectType) => false;
    }

    class Competitor
    {
        [JsonProperty("team")]
        public Team Team;

        [JsonProperty("homeAway")]
        public string HomeAway;

        [JsonProperty("records"), JsonConverter(typeof(RecordsConverter))]
        public Record Record;

        public bool IsHome => HomeAway == "home";
        public bool IsAway => !IsHome;
    }

    class Team
    {
        [JsonProperty("abbreviation")]
        public string Abbreviation;

        [JsonProperty("displayName")]
        public string Name;

        [JsonProperty("location")]
        public string Location;
    }

    class OddsFavorite
    {
        public string TeamAbbreviation;
        public decimal Spread;
    }

    class OddsFavoriteConverter : JsonConverter
    {
        public override object ReadJson(JsonReader reader, Type objectType, object existingValue, JsonSerializer serializer) {
            string value = (string)JObject.ReadFrom(reader);
            var parts = value.Split(' ', 2);
            return new OddsFavorite {
                TeamAbbreviation = parts[0],
                Spread = decimal.Parse(parts[1])
            };
        }

        public override void WriteJson(JsonWriter writer, object value, JsonSerializer serializer) { }
        public override bool CanWrite => false;
        public override bool CanConvert(Type objectType) => false;
    }

    class Odds
    {
        [JsonProperty("provider")]
        public OddsProvider Provider;

        [JsonProperty("details"), JsonConverter(typeof(OddsFavoriteConverter))]
        public OddsFavorite Favorite;

        [JsonProperty("overUnder")]
        public decimal OverUnder;
    }

    class OddsProvider
    {
        [JsonProperty("id")]
        public int Id;
    }
}
