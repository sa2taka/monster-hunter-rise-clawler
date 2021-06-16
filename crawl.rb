require 'anemone'

URL = "https://appmedia.jp/mhrise/6185863"
MONSTERS_URL = "https://game8.jp/mhrise/363818"

monster_file = File.open("./result/monster.ts", "w")
quest_file = File.open("./result/quest.ts", "w")

normal_monsters = ["イズチ", "ウロコトル", "オルタロス", "ケストドン", "ジャギィ", "ジャグラス", "スクアギル", "ツケヒバキ", "バギィ", "ブナハブラ", "ブルファンゴ", "フロギィ", "ブンブジナ", "ルドロス"]

monster_class = <<~'EOS'
export interface Monster {
  name: string;
  image: string;
  apex: boolean;
  old: boolean;
}

export const Monsters: Monster[] = [
EOS

quest_class = <<~'EOS'
export interface Quest {
  name: string;
  level: number;
  type: string;
  monsters: string[];
}

export const Quests: Quest[] = [
EOS

monster_file.write(monster_class)
quest_file.write(quest_class)


quest = []

Anemone.crawl(URL, :depth_limit => 0) do |anemone|
  anemone.on_every_page do |page|
    page.doc.xpath("//table[@id='mhrise_data_all']/tbody/tr[contains(@class,'mhrise_data_tr')]").each do |data|
      children = data.xpath("td")
      level_m = children[0].text.match(/\d+/)
      next unless level_m

      level = level_m[0]
      quest_name = children[1].text
      type = children[2].text
      case type
      when /^緊急/
        type = type.match(/\[(.+)\]/)[1]
      when /^イベント/
        type = "イベント"
      end

      q_monsters = children[3].xpath("a").map { |monster| monster.text }
      next if q_monsters.any? { |m| normal_monsters.include?(m) }

      quest.push(name: quest_name, level: level, type: type, monsters: q_monsters)
    end
  end
end

monsters = {}

Anemone.crawl(MONSTERS_URL, :depth_limit => 0) do |anemone|
  anemone.on_every_page do |page|
    data_tables = page.doc.xpath("//table[contains(@class, 'a-table')]")[1, 4]
    # correctly xpath is "tbody/tr/td", but it does not behavior.
    data_tables[0].xpath("*/*/*").each do |monster_data|
      monsters.merge!(monster_data.text => {})
    end

    data_tables[2].xpath("*/*/*").each do |monster_data|
      monsters.merge!(monster_data.text => {}) unless monsters[monster_data.text]
      monsters[monster_data.text].merge!(old: true)
    end

    data_tables[3].xpath("*/*/*").each do |monster_data|
      monsters.merge!(monster_data.text => {}) unless monsters[monster_data.text]
      monsters[monster_data.text].merge!(apex: true)
    end
  end
end


def toM(monster, opt)
  <<~"EOS"
{
  name: "#{monster}",
  image: "#{monster}.png",
  apex: #{!!opt[:apex]},
  old: #{!!opt[:old]},
},
  EOS
end

monster_file.write(monsters.map do |monster, value|
  toM(monster, value)
end.join("\n"))
monster_file.write("]")

quest_file.write(quest.map do |q|
  <<~"EOS"
{
  name: "#{q[:name]}",
  level: #{q[:level]},
  type: "#{q[:type]}",
  monsters: [
    #{q[:monsters].map { |m| "\"#{m}\""}.join(",")}
  ],
},
  EOS
end.join("\n"))
quest_file.write("]")

monster_file.close()
quest_file.close()
