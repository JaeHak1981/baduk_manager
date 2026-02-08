import '../models/education_report_model.dart';

class DefaultReportTemplates {
  static List<CommentTemplateModel> getTemplates() {
    return [
      // 1. 인트로 (Intro) - 이름을 불러주며 시작
      CommentTemplateModel(
        id: 'i1',
        category: '인트로',
        content: '{{name}} 학생은 바둑 실력이 향상되며 한층 더 성장한 모습을 보여주었습니다.',
      ),
      CommentTemplateModel(
        id: 'i2',
        category: '인트로',
        content: '{{name}} 학생은 꾸준한 노력과 열정으로 실력을 쌓아가는 중이며, 학습 현황을 전해드립니다.',
      ),
      CommentTemplateModel(
        id: 'i3',
        category: '인트로',
        content: '{{name}} 학생은 집중력 있는 모습으로 매 수업에 임하며 순조롭게 바둑 공부를 진행하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'i4',
        category: '인트로',
        content: '{{name}} 학생은 최근 기술적인 발전뿐만 아니라 바둑을 대하는 마음가짐도 더욱 성숙해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'i5',
        category: '인트로',
        content: '{{name}} 학생은 꾸준히 학습하며 바둑의 기본기를 탄탄하게 다져가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'i6',
        category: '인트로',
        content: '{{name}} 학생은 정석과 수읽기를 익히며 실전 대국 능력이 크게 향상되어 성장이 매우 기쁩니다.',
      ),
      CommentTemplateModel(
        id: 'i7',
        category: '인트로',
        content: '{{name}} 학생은 바둑의 이치를 하나씩 깨달아가며 바둑 두는 즐거움을 알아가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'i8',
        category: '인트로',
        content: '{{name}} 학생은 매 수업 시간 반짝이는 눈빛으로 새로운 정석을 익히며 돋보이는 발전을 보여줍니다.',
      ),

      // 2. 학습 성취 (Achievement)
      // [Level 1: 입문/기초]
      CommentTemplateModel(
        id: 'a1_1',
        category: '학습 성취',
        level: 1,
        content: '기초 규칙을 완벽히 이해하고 돌의 활로 및 집의 개념을 정확히 구분하여 적용합니다.',
      ),
      CommentTemplateModel(
        id: 'a1_2',
        category: '학습 성취',
        level: 1,
        content: '단수와 따내기 등 바둑의 가장 기본이 되는 원리를 실전 대국에서 실수 없이 수행해냅니다.',
      ),
      CommentTemplateModel(
        id: 'a1_3',
        category: '학습 성취',
        level: 1,
        content: '착수 금지와 패의 규칙 등 자칫 헷갈리기 쉬운 부분들도 이제는 정확히 숙지하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_4',
        category: '학습 성취',
        level: 1,
        content: "두 집을 만들어야 산다는 '사활'의 기본 원리를 이해하고 실전에서 적용하려 노력합니다.",
      ),
      CommentTemplateModel(
        id: 'a1_5',
        category: '학습 성취',
        level: 1,
        content: '상대방 돌을 잡는 것에만 몰두하지 않고 내 돌을 연결하여 튼튼하게 만드는 법을 익히고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_6',
        category: '학습 성취',
        level: 1,
        content: '서로 단수에 걸린 상황에서 침착하게 먼저 따내는 수를 찾아내는 감각이 좋아졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_7',
        category: '학습 성취',
        level: 1,
        content: '바둑판의 귀와 변, 중앙의 명칭을 명확히 알고 있으며 첫 수를 어디에 두어야 할지 이해하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_8',
        category: '학습 성취',
        level: 1,
        content: '내 돌이 위험할 때 달아나는 방법과 상대 돌을 포위하는 방법을 구별하여 사용할 줄 압니다.',
      ),
      CommentTemplateModel(
        id: 'a1_9',
        category: '학습 성취',
        level: 1,
        content: '옥집과 진짜 집을 구별하는 눈을 가지게 되었으며, 집을 짓는 기초 원리를 잘 따르고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_10',
        category: '학습 성취',
        level: 1,
        content: '축과 장문의 원리를 이해하여, 도망가는 상대 돌을 효율적으로 잡아내는 기술을 익혔습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_11',
        category: '학습 성취',
        level: 1,
        content: '상대가 내 집을 부수러 들어왔을 때 당황하지 않고 막아내는 수비력이 생기기 시작했습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_12',
        category: '학습 성취',
        level: 1,
        content: '단순히 돌을 놓는 것이 아니라, 집을 더 넓게 짓기 위해 선을 긋는 감각을 익히고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a1_13',
        category: '학습 성취',
        level: 1,
        content: '환격의 묘수를 이해하고 실전에서 상대를 깜짝 놀라게 하는 수를 찾아내기도 합니다.',
      ),

      // [Level 2: 초급/실전]
      CommentTemplateModel(
        id: 'a2_1',
        category: '학습 성취',
        level: 2,
        content: "착점의 우선순위인 '큰 자리'를 스스로 찾아내며 판 전체를 넓게 보는 안목이 생겼습니다.",
      ),
      CommentTemplateModel(
        id: 'a2_2',
        category: '학습 성취',
        level: 2,
        content: '집 짓기의 효율성을 이해하기 시작했으며, 돌이 끊기지 않도록 연결하는 능력이 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_3',
        category: '학습 성취',
        level: 2,
        content: '수상전 상황에서 상대의 수를 줄이고 나의 수를 늘리는 요령을 터득하여 승률이 높아졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_4',
        category: '학습 성취',
        level: 2,
        content: '빈삼각과 같은 나쁜 모양을 피하고 호구와 같은 탄력 있는 좋은 모양을 갖추려 노력합니다.',
      ),
      CommentTemplateModel(
        id: 'a2_5',
        category: '학습 성취',
        level: 2,
        content: '상대의 세력을 삭감하거나 내 영역을 넓히는 행마법을 실전에서 자연스럽게 구사합니다.',
      ),
      CommentTemplateModel(
        id: 'a2_6',
        category: '학습 성취',
        level: 2,
        content: '포석 단계에서 귀-변-중앙의 순서로 집을 넓혀가는 기본 원리를 잘 지키고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_7',
        category: '학습 성취',
        level: 2,
        content: '침입해온 상대 돌을 무조건 잡으러 가기보다 공격을 통해 이득을 취하는 유연한 사고가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'a2_8',
        category: '학습 성취',
        level: 2,
        content: '간단한 사활 문제는 한 눈에 정답을 찾아낼 정도로 기본적인 수읽기 속도가 빨라졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_9',
        category: '학습 성취',
        level: 2,
        content: '패를 활용하여 불리한 상황을 반전시키거나 상대를 굴복시키는 전술적 활용 능력이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_10',
        category: '학습 성취',
        level: 2,
        content: "돌을 무겁게 뭉치지 않게 하고 가볍게 움직이는 '행마의 기초'를 이해하고 있습니다.",
      ),
      CommentTemplateModel(
        id: 'a2_11',
        category: '학습 성취',
        level: 2,
        content: '상대의 무리한 공격을 응징하고, 나의 약점은 미리 지키는 공수 균형 감각이 좋아졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_12',
        category: '학습 성취',
        level: 2,
        content: '정석 진행 중 손을 빼야 할 때와 받아주어야 할 때를 구분하는 판단력이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'a2_13',
        category: '학습 성취',
        level: 2,
        content: '양단수와 같은 상대의 약점을 놓치지 않고 찔러가며 이득을 보는 눈이 날카롭습니다.',
      ),

      // [Level 3: 중고급/심화]
      CommentTemplateModel(
        id: 'a3_1',
        category: '학습 성취',
        level: 3,
        content: '복잡한 사활 문제도 침착하게 수읽기하여 정답을 찾아내는 해결 능력이 우수합니다.',
      ),
      CommentTemplateModel(
        id: 'a3_2',
        category: '학습 성취',
        level: 3,
        content: '중반 전투 시 상대의 약점을 예리하게 파고드는 공격적인 수읽기가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'a3_3',
        category: '학습 성취',
        level: 3,
        content: '형세 판단을 통해 현재의 유불리를 파악하고, 그에 맞는 전략을 세우는 능력이 탁월합니다.',
      ),
      CommentTemplateModel(
        id: 'a3_4',
        category: '학습 성취',
        level: 3,
        content: '부분적인 전투 승리보다 전체적인 판의 균형을 중시하는 대세관이 형성되고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_5',
        category: '학습 성취',
        level: 3,
        content: '상대의 의도를 미리 파악하고 그에 대응하는 반격 수단을 준비하는 등 수읽기의 깊이가 깊어졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_6',
        category: '학습 성취',
        level: 3,
        content: '두터움을 활용하여 장기적인 이득을 도모하거나 상대를 압박하는 운영 능력이 수준급입니다.',
      ),
      CommentTemplateModel(
        id: 'a3_7',
        category: '학습 성취',
        level: 3,
        content: '사석 작전을 통해 불필요한 돌을 버리고 더 큰 이익을 취하는 고도의 전술을 구사하기도 합니다.',
      ),
      CommentTemplateModel(
        id: 'a3_8',
        category: '학습 성취',
        level: 3,
        content: '정교한 끝내기 수순을 통해 미세한 승부에서도 역전승을 이끌어내는 뒷심이 강해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_9',
        category: '학습 성취',
        level: 3,
        content: '고정관념에 얽매이지 않는 창의적인 수를 시도하며 자신만의 기풍을 만들어가고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_10',
        category: '학습 성취',
        level: 3,
        content: '약한 돌을 수습하는 타개 능력이 뛰어나 위기 상황에서도 쉽게 무너지지 않는 끈기를 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'a3_11',
        category: '학습 성취',
        level: 3,
        content: "'선수'의 중요성을 깊이 이해하고 있으며, 주도권을 뺏기지 않으려 노력합니다.",
      ),
      CommentTemplateModel(
        id: 'a3_12',
        category: '학습 성취',
        level: 3,
        content: '불리한 바둑에서도 쉽게 포기하지 않고 승부수(승부 호흡)를 던질 줄 아는 담대함이 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_13',
        category: '학습 성취',
        level: 3,
        content: '상대의 모양을 무너뜨리는 급소를 정확히 타격하여 전세를 뒤집는 펀치력이 있습니다.',
      ),
      CommentTemplateModel(
        id: 'a3_14',
        category: '학습 성취',
        level: 3,
        content: '단순히 집을 짓는 것을 넘어, 상대의 발전 가능성을 견제하는 고차원적인 전략을 구사합니다.',
      ),

      // 3. 학습 태도 (Attitude)
      CommentTemplateModel(
        id: 't1',
        category: '학습 태도',
        content: '수업 시간 내내 높은 몰입도를 유지하며 선생님의 설명에 귀를 기울이는 자세가 매우 좋습니다.',
      ),
      CommentTemplateModel(
        id: 't2',
        category: '학습 태도',
        content: '궁금한 원리에 대해 적극적으로 질문하고 답을 찾으려는 탐구적인 태도가 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 't3',
        category: '학습 태도',
        content: '패배에 실망하기보다 복기를 통해 자신의 실수를 돌아보는 진지한 자세를 갖고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't4',
        category: '학습 태도',
        content: '한 수 한 수 신중하게 생각하고 두려는 노력이 보이며, 경솔한 착점이 눈에 띄게 줄었습니다.',
      ),
      CommentTemplateModel(
        id: 't5',
        category: '학습 태도',
        content: '모르는 문제가 나와도 포기하지 않고 스스로 끝까지 해결해 보려는 의지가 강합니다.',
      ),
      CommentTemplateModel(
        id: 't6',
        category: '학습 태도',
        content: '바른 자세로 앉아 흐트러짐 없이 대국에 임하며, 상대를 배려하는 마음가짐이 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 't7',
        category: '학습 태도',
        content: '자신의 차례가 아닐 때도 상대의 수를 주의 깊게 관찰하며 생각하는 습관이 잘 잡혀 있습니다.',
      ),
      CommentTemplateModel(
        id: 't8',
        category: '학습 태도',
        content: "어려운 상황에서도 짜증 내지 않고 차분함을 유지하는 '평정심'을 지키는 능력이 좋습니다.",
      ),
      CommentTemplateModel(
        id: 't9',
        category: '학습 태도',
        content: '과제를 성실하게 수행해 오며, 배운 내용을 복습하려는 자기 주도적인 학습 태도를 갖추고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't10',
        category: '학습 태도',
        content: '친구들과의 대국이나 교류 활동에도 적극적으로 참여하며 즐겁게 바둑을 배우고 있습니다.',
      ),
      CommentTemplateModel(
        id: 't11',
        category: '학습 태도',
        content: '선생님의 조언을 열린 마음으로 받아들이고 즉시 자신의 플레이에 적용하려는 유연함이 장점입니다.',
      ),
      CommentTemplateModel(
        id: 't12',
        category: '학습 태도',
        content: '대국이 끝난 후 승패와 상관없이 바둑판을 스스로 정리 정돈하는 습관이 아주 잘 잡혀 있습니다.',
      ),
      CommentTemplateModel(
        id: 't13',
        category: '학습 태도',
        content: '다른 친구들의 대국을 관전할 때 훈수를 두지 않고 조용히 지켜보는 매너가 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 't14',
        category: '학습 태도',
        content: '어려운 사활 문제를 풀 때도 답지를 보려 하기보다 끈질기게 생각하여 풀어내는 집념이 있습니다.',
      ),
      CommentTemplateModel(
        id: 't15',
        category: '학습 태도',
        content: '실수한 수를 두었을 때도 바로 손을 대거나 무르자고 하지 않고 결과를 받아들이는 정직함이 있습니다.',
      ),
      CommentTemplateModel(
        id: 't16',
        category: '학습 태도',
        content: '자신보다 실력이 낮은 친구를 배려하며 친절하게 가르쳐주는 모습이 대견합니다.',
      ),

      // 4. 대국 예절 (Etiquette)
      CommentTemplateModel(
        id: 'e1',
        category: '대국 매너',
        content: '대국 전후의 인사를 빠뜨리지 않으며 상대방을 존중하는 바둑인의 자세가 매우 바릅니다.',
      ),
      CommentTemplateModel(
        id: 'e2',
        category: '대국 매너',
        content: '승패 결과보다는 대국의 과정에 집중하며 승부의 세계를 건전하게 즐기는 모습이 보기 좋습니다.',
      ),
      CommentTemplateModel(
        id: 'e3',
        category: '대국 매너',
        content: '대국 중 정숙을 유지하고 상대방의 생각 시간을 배려하는 매너 있는 태도가 돋보입니다.',
      ),
      CommentTemplateModel(
        id: 'e4',
        category: '대국 매너',
        content: '바둑판과 바둑알을 소중히 다루며, 대국 후 정리 정돈까지 완벽하게 해냅니다.',
      ),
      CommentTemplateModel(
        id: 'e5',
        category: '대국 매너',
        content: '상대가 장고할 때 재촉하지 않고 기다려주는 인내심과 배려심을 갖추고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'e6',
        category: '대국 매너',
        content: '승리했을 때 자만하지 않고 패배한 상대를 위로할 줄 아는 성숙한 태도를 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e7',
        category: '대국 매너',
        content: '패배했을 때도 상대방의 좋은 수를 칭찬하며 깨끗하게 결과에 승복하는 스포츠맨십이 훌륭합니다.',
      ),
      CommentTemplateModel(
        id: 'e8',
        category: '대국 매너',
        content: '대국 중 불필요한 말이나 행동을 삼가고 오직 반상 승부에만 집중하는 진지함을 갖추었습니다.',
      ),
      CommentTemplateModel(
        id: 'e9',
        category: '대국 매너',
        content: '돌을 놓을 때 바른 손모양과 자세를 유지하며 품격 있는 대국 태도를 보여줍니다.',
      ),
      CommentTemplateModel(
        id: 'e10',
        category: '대국 매너',
        content: '계가 과정에서 상대방과 협력하여 정확하게 집을 세고 결과를 확인하는 절차를 잘 따릅니다.',
      ),

      // 5. 성장 변화 (Growth)
      CommentTemplateModel(
        id: 'g1',
        category: '성장 변화',
        content: '초기 대비 바둑판을 보는 시야가 넓어졌으며 착점 시의 자신감이 크게 향상되었습니다.',
      ),
      CommentTemplateModel(
        id: 'g2',
        category: '성장 변화',
        content: '단순히 돌을 따내기보다 판 전체를 보며 집을 지으려는 거시적인 안목이 생기기 시작했습니다.',
      ),
      CommentTemplateModel(
        id: 'g3',
        category: '성장 변화',
        content: '수읽기 능력이 정교해지면서 실전 대국에서의 승률 또한 눈에 띄게 상승하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g4',
        category: '성장 변화',
        content: '자신보다 상위 급수의 친구에게도 위축되지 않고 대등한 경기를 펼칠 만큼 담력이 커졌습니다.',
      ),
      CommentTemplateModel(
        id: 'g5',
        category: '성장 변화',
        content: '예전에는 실수하면 당황했으나, 이제는 침착하게 수습하고 다음 기회를 노리는 위기관리 능력이 생겼습니다.',
      ),
      CommentTemplateModel(
        id: 'g6',
        category: '성장 변화',
        content: '단수만 보던 시야에서 벗어나 돌의 연결과 끊음을 동시에 고려하는 입체적인 사고가 가능해졌습니다.',
      ),
      CommentTemplateModel(
        id: 'g7',
        category: '성장 변화',
        content: '기보를 보거나 문제를 풀 때 정답을 맞히는 속도가 빨라졌으며 직관적인 감각이 발달하고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g8',
        category: '성장 변화',
        content: '바둑을 통해 키워진 집중력과 인내심이 평소 생활 태도에서도 긍정적인 변화로 나타나고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g9',
        category: '성장 변화',
        content: '자신만의 특기 전법이 생기기 시작하여 바둑 두는 재미를 한층 더 느끼고 있습니다.',
      ),
      CommentTemplateModel(
        id: 'g10',
        category: '성장 변화',
        content: '어려운 사활 문제에 도전하는 것을 즐기며, 끈기 있게 생각하는 힘이 몰라보게 길러졌습니다.',
      ),

      // 6. 마무리 (Conclusion) - 마지막 여운을 위해 이름 포함 가능
      CommentTemplateModel(
        id: 'c1',
        category: '마무리',
        content: '지금처럼 바둑을 즐기며 성실하게 노력한다면 머지않아 훌륭한 기량을 갖추게 될 것입니다.',
      ),
      CommentTemplateModel(
        id: 'c2',
        category: '마무리',
        content: '앞으로의 멋진 성장을 기대하며 적극적으로 지원하고 지도하겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c3',
        category: '마무리',
        content: '바둑을 통해 키운 수읽기 능력과 인내심이 다른 학습에도 긍정적인 영향을 미치길 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c4',
        category: '마무리',
        content: '다음 달에는 더욱 발전된 모습으로 깊이 있는 바둑을 함께 연구해 나가기를 희망합니다.',
      ),
      CommentTemplateModel(
        id: 'c5',
        category: '마무리',
        content: '꾸준함이 가장 큰 무기입니다. 앞날의 밝은 미래를 응원합니다.',
      ),
      CommentTemplateModel(
        id: 'c6',
        category: '마무리',
        content: '가정에서도 바둑을 통해 얻는 성취감을 함께 나누고 격려해 주시기 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c7',
        category: '마무리',
        content: '다음 단계로 도약하기 위한 중요한 시기인 만큼, 더욱 세심한 지도로 이끌어 나가겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c8',
        category: '마무리',
        content: '바둑을 통해 배운 지혜가 앞으로의 삶에 든든한 밑거름이 되기를 소망합니다.',
      ),
      CommentTemplateModel(
        id: 'c9',
        category: '마무리',
        content: '무한한 잠재력을 믿으며, 앞으로도 즐거운 바둑 수업이 되도록 노력하겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c10',
        category: '마무리',
        content: '한 판의 바둑을 완성하듯, 자신의 꿈을 멋지게 그려나갈 수 있도록 돕겠습니다.',
      ),
      CommentTemplateModel(
        id: 'c11',
        category: '마무리',
        content: '함께 바둑을 공부하는 시간이 행복한 추억이자 성장의 기회가 되길 바랍니다.',
      ),
      CommentTemplateModel(
        id: 'c12',
        category: '마무리',
        content: '승급을 목표로 더욱 정진하는 모습에 아낌없는 칭찬과 응원을 부탁드립니다.',
      ),
    ];
  }
}
