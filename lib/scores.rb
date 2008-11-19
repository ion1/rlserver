CRAWL_FILENAME = "/var/games/crawl/scores"
CRAWL_HTML     = "/home/www/rlserver/public/crawl.html"

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
    <table>
      <thead><tr align="left"><th>#</th><th>Name</th><th>Player Points</th><th>Bonus Points</th><th>Total Score</th><th>Best</th></tr></thead>
      <tbody>#{i=0;score.total_points.sort{|x,y|y[1] <=> x[1]}.map{|x| "<tr><td>#{i+=1}</td><td>#{x[0]}</td><td>#{score.player_points[x[0]].to_i}</td><td>#{score.bonus_points[x[0]].to_i*score.bonus_mult}</td><td>#{x[1]}</td><td>#{score.bonuses[x[0]].join(", ")}</td></tr>"}.join("\n")}</tbody>
    </table>
    <table>
      <thead><tr align="left"><th>#</th><th>Name</th><th>Race/Class</th><th>HP</th><th>Dungeon</th><th>Score</th><th>Killer</th><th>with</th></tr></thead>
      <tbody>#{i=0;score.data.map{|points| "<tr><td>#{i+=1}</td><td>#{points["name"]}</td><td>#{points["race"]} #{points["cls"]} (lvl:#{points["xl"]})</td><td>#{points["hp"]}/#{points["mhp"]}</td><td>#{points["br"]}:#{points["lvl"]}<td>#{points["sc"]}</td><td>#{points["killer"]}</td><td>#{points["kaux"]}</td></tr>"}.join("\n")}</tbody>
    </table>
  </body>
</html>
HTML_END
    File.open(CRAWL_HTML, "w") {|file| file.write(html)}
  end
end
