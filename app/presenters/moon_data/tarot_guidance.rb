# Orientações de leitura de tarô por fase lunar (pt-BR).
# Baseado em: http://tarotwithgord.com/best-moon-phase-for-tarot-reading/
class MoonData::TarotGuidance
  SOURCE_NAME = "Tarot with Gord".freeze
  SOURCE_URL  = "http://tarotwithgord.com/best-moon-phase-for-tarot-reading/".freeze

  # Chaveado pelo nome bruto da fase devolvido pela API (normalizado:
  # minúsculas, espaços trocados por "_"). Cada entrada traz um título curto
  # e um corpo com a recomendação de leitura.
  GUIDANCE = {
    "new_moon" => {
      title: "Defina intenções",
      body: "Energia calma e intuitiva, ideal para recomeços. Boas leituras para plantar intenções, abrir novos caminhos e olhar para possibilidades futuras."
    },
    "waxing_crescent" => {
      title: "Trace metas",
      body: "Clima esperançoso e voltado ao futuro. Momento para definir objetivos, fazer um planejamento inicial e buscar motivação para o que está nascendo."
    },
    "first_quarter" => {
      title: "Hora de agir",
      body: "Fase de decisão e ação. As leituras ajudam a resolver problemas, encarar obstáculos e mostrar onde é preciso dar o próximo passo."
    },
    "waxing_gibbous" => {
      title: "Ajuste a rota",
      body: "Tempo de refinar e aperfeiçoar. Conselhos práticos e aterrados para melhorar planos que já estão em andamento, em vez de começar do zero."
    },
    "full_moon" => {
      title: "Verdades reveladas",
      body: "Auge de iluminação e intuição. Leituras profundas que trazem clareza emocional, revelam verdades ocultas e ampliam a consciência."
    },
    "waning_gibbous" => {
      title: "Reflita e revise",
      body: "Fase de processar e revisar. Boas leituras para dar sentido ao que foi vivido e assimilar aprendizados, mais do que buscar novidades."
    },
    "last_quarter" => {
      title: "Solte e encerre",
      body: "Momento de liberação e fechamento. As leituras apontam o que precisa ser solto e ajudam a limpar energias e ciclos antigos."
    },
    "waning_crescent" => {
      title: "Descanse a intuição",
      body: "Energia baixa, menos favorável a leituras. Período para repousar, recolher-se e esperar o novo ciclo antes de buscar respostas."
    }
  }.freeze

  DEFAULT = {
    title: "Leitura lunar do dia",
    body: "Observe o céu com calma e use o boletim como bússola para o ritmo do seu dia."
  }.freeze

  # Orientação extra quando o evento for uma lua especial (super lua, lua azul...).
  SPECIAL_GUIDANCE = {
    title: "Lua especial",
    body: "Evento raro no céu: uma boa oportunidade para leituras com intenção reforçada e rituais mais marcantes."
  }.freeze

  def self.for(phase_name)
    GUIDANCE.fetch(normalize(phase_name), DEFAULT)
  end

  def self.normalize(phase_name)
    phase_name.to_s.strip.gsub(" ", "_").downcase
  end
end
