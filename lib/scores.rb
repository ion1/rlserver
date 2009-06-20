CRAWL_FILENAME = "/var/games/crawl/saves/scores"
CRAWL_HTML = "crawl.html"
COLORS = ["odd", "even"]

module Scores
  class CrawlScores
    attr_reader :player_points, :bonus_points, :total_points, :bonus_mult, :data, :bonuses
    def initialize(filename)
      @data = []
      File.open(filename) do |file|
        file.read.each_line do |line|
          dataset = {}
          line.split(":").each do |pair|
            key, value = pair.split("=")
            dataset[key] = value
          end
          @data << dataset
        end
      end
      @player_points = {}
      @data.each do |dat|
        @player_points[dat["name"]] = @player_points[dat["name"]].to_i + dat["sc"].to_i
      end
      
      race = []
      cls  = []
      @bonus_points = {}
      @bonuses = {}
      @data.each do |dat|
        if not @bonuses.member?(dat["name"]) then @bonuses[dat["name"]] = [[],[]] end
        if not race.member? dat["race"]
          race << dat["race"]
          @bonus_points[dat["name"]] = @bonus_points[dat["name"]].to_i + 1
          @bonuses[dat["name"]][0] << dat["race"]
        end
        if not cls.member? dat["cls"]
          cls << dat["cls"]
          @bonus_points[dat["name"]] = @bonus_points[dat["name"]].to_i + 1
          @bonuses[dat["name"]][1] << dat["cls"]
        end
      end

      @bonus_mult = @player_points.values.inject{|x,y|x+y}/100.0
      @total_points = {}
      @player_points.each do |key, val|
        @total_points[key] = @total_points[key].to_i + val
      end
      @bonus_points.each do |key, val|
        @total_points[key] = @total_points[key].to_f + val * @bonus_mult
      end
    end
    def range_type_verb(score)
      case score["kaux"][0,4]
      when "Shot": return "Shot"
      when "Hit ", "voll": return "Hit from afar"
      else return "Blasted"
      end
    end
    def damage_verb(score)
      if score["hp"].to_i > -6 then return "Slain"
      elsif score["hp"].to_i > -14 then return "Mangled"
      elsif score["hp"].to_i > -22 then return "Demolished"
      else return "Annihilated"
      end
    end
    def strip_article_a(s)
      if s["a "] == " a"
        return s.delete("a ")
      elsif s["an "] == "an "
        return s.delete("an ")
      else return s
      end
    end
    def death_source_desc(score)
      if score["ktyp"] != "beam" and score["ktyp"] != "mon" then return "" end
      if score["killer"] == "" then return "" else return score["killer"] end
    end
    def death_description(score)
      needs_beam_cause_line = false
      needs_called_by_monster_line = false
      #needs_damage = false
      desc=""
      case score["ktyp"]
      when "mon": 
        desc += damage_verb(score) + " by " + death_source_desc(score)
        #if score["kaux"] != nil then desc += " with " + score["kaux"] end
      when "pois": desc += "Succumbed to poison"
      when "cloud": desc += "Engulfed by a cloud of #{score["kaux"]}"
      when "beam": 
        desc += range_type_verb(score) + " by " + death_source_desc(score)
      when "lava":
        if score["race"] == "Mummy" then
          desc += "Turned to ash by lava"
        else
          desc += "Took a swim in molten lava"
        end
      when "water":
        if score["race"] == "Mummy" then
          desc += "Soaked and fell apart"
        else
          desc += "Drowned"
        end
      when "trap":
        desc += "Killed by triggering " + score["kaux"] + " trap"
      when "leaving":
        if score["nrune"].to_i > 0 then
          desc += "Got out of the dungeon"
        else
          desc += "Got out of the dungeon alive"
        end
      when "winning":
        desc += "Escaped with the Orb"
        if score["nrune"].to_i < 1 then desc += "!" end
      when "quitting":
        desc += "Quit"
      when "draining":
        desc += "Was drained of all life"
      when "starvation":
        desc += "Starved to death"
      when "freezing":
        desc += "Froze to death"
      when "burning":
        desc += "Burnt to a crisp"
      when "wild_magic":
        if score["kaux"]["by "] == "by " then
          desc =+ "Killed " + score["kaux"]
        else
          desc += "Killed by " + score["kaux"]
        end
      when "statue":
        desc += "Killed by a statue"
      when "rotting":
        desc += "Rotted away"
      when "targeting":
        desc += "Killed themselves with bad targetting"
      when "spore":
        desc += "Killed by an exploding spore"
      when "tso_smiting":
        desc += "Smote by The Shining One"
      when "petrification":
        desc += "Turned to stone"
      when "unknown":
        desc += "Died"
      when "falling_down_stairs":
        desc += "Fell down a flight of stairs"
      when "acid":
        desc += "Splashed by acid"
      when "curare":
        desc += "Asphyxiated"
      when "melting":
        desc += "Melted into a puddle"
      when "bleeding":
        desc += "Bled to death"
      when "something":
        desc += "Nibbled to death by software bugs"
      when "stupidity":
        desc += "Forgot to breathe"
      end
      if score["nrune"].to_i > 0 then
        desc += " (with #{score["nrune"]} rune#{if score["nrune"].to_i > 1 then "s" end})"
      end
      return desc
    end
  end

  def self.updatecrawl
    score = CrawlScores.new(CRAWL_FILENAME)
    html = <<HTML_END
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html>
  <head>
    <title>Crawl Scores</title>
    <script type="text/javascript" src="sortabletable/js/sortabletable.js"></script>
    <link rel="stylesheet" type="text/css" href="sortabletable/css/sortabletable.css"/>
    <link rel="stylesheet" type="text/css" href="style.css"/>
  </head>
  <body>
    <p>
    <table class="sort-table" id="player-ranking">
      <thead><tr align="left"><th>#</th><th>Name</th><th>Player Points</th><th>Bonus Points</th><th>Total Score</th><th>Best</th></tr></thead>
      <tbody>#{i=0;score.total_points.sort{|x,y|y[1] <=> x[1]}.map{|x| "<tr class=#{COLORS[i % 2]}><td>#{i+=1}</td><td>#{x[0]}</td><td>#{score.player_points[x[0]].to_i}</td><td>#{score.bonus_points[x[0]].to_i*score.bonus_mult}</td><td>#{x[1]}</td><td>#{score.bonuses[x[0]].join(", ")}</td></tr>"}.join("\n")}</tbody>
    </table>
    </p>
    <p>
    <table class="sort-table" id="scores">
      <thead><tr align="left"><th>#</th><th>Name</th><th>Race/Class</th><th>HP</th><th>Dungeon</th><th>Score</th><th>Turns</th><th>Quit reason</th></tr></thead>
      <tbody>#{i=0;score.data.map{|points| "<tr class=#{COLORS[i % 2]}><td>#{i+=1}</td><td>#{points["name"]}</td><td>#{points["race"]} #{points["cls"]} (lvl:#{points["xl"]})</td><td>#{points["hp"]}/#{points["mhp"]}</td><td>#{points["br"]}:#{points["lvl"]}<td>#{points["sc"]}</td><td>#{points["turn"]}<td>#{score.death_description(points)}</td></tr>"}.join("\n")}</tbody>
    </table>
    </p>
    <script type="text/javascript">
    function addClassName(el, sClassName)
    {
        var s = el.className;
        var p = s.split(" ");
        var l = p.length;
        for (var i = 0; i < l; i++)
        {
            if (p[i] == sClassName)
            return;
        }
        p[p.length] = sClassName;
        el.className = p.join(" ").replace( /(^\\s+)|(\\s+\$)/g, "" );
    }
    function removeClassName(el, sClassName)
    {
        var s = el.className;
        var p = s.split(" ");
        var np = [];
        var l = p.length;
        var j = 0;
        for (var i = 0; i < l; i++)
        {
            if (p[i] != sClassName)
            np[j++] = p[i];
        }
        el.className = np.join(" ").replace( /(^\\s+)|(\\s+\$)/g, "" );
    }
    var st1 = new SortableTable(document.getElementById("player-ranking"),["Number", "CaseInsensitiveString", "Number", "Number", "Number", "CaseInsensitiveString"]);
    st1.onsort = function ()
    {
        var rows = st1.tBody.rows;
        var l = rows.length;
        for (var i = 0; i < l; i++)
        {
            removeClassName(rows[i], i % 2 ? "odd" : "even");
            addClassName(rows[i], i % 2 ? "even" : "odd");
        }
    };
    </script>
  </body>
</html>
HTML_END
    File.open(CRAWL_HTML, "w") {|file| file.write(html)}
  end
end
