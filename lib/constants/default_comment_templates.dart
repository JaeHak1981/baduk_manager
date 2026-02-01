import '../models/education_report_model.dart';

/// 기본 바둑 교육 통지표 템플릿 문구 라이브러리
///
/// AI Off 모드에서 사용되며, AI On 모드에서는 참고 자료(TAG)로 활용됩니다.
List<CommentTemplateModel> getDefaultCommentTemplates() {
  return [
    // 인트로 (Intro)
    CommentTemplateModel(
      id: 'i1',
      category: '인트로',
      content: '{{name}} 학생은 이번 기간 동안 바둑 실력이 꾸준히 향상되고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'i2',
      category: '인트로',
      content: '{{name}} 학생은 매 수업마다 진지한 자세로 바둑 학습에 임하고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'i3',
      category: '인트로',
      content: '{{name}} 학생의 바둑 실력이 눈에 띄게 성장하고 있어 기쁩니다.',
    ),
    CommentTemplateModel(
      id: 'i4',
      category: '인트로',
      content: '{{name}} 학생은 바둑을 통해 사고력과 집중력을 키워가고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'i5',
      category: '인트로',
      content: '{{name}} 학생의 바둑 학습 태도가 매우 모범적입니다.',
    ),
    CommentTemplateModel(
      id: 'i6',
      category: '인트로',
      content: '{{name}} 학생은 바둑에 대한 열정과 흥미를 잃지 않고 꾸준히 노력하고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'i7',
      category: '인트로',
      content: '{{name}} 학생은 이번 달 {{textbook}} 학습을 통해 한 단계 성장하였습니다.',
    ),
    CommentTemplateModel(
      id: 'i8',
      category: '인트로',
      content: '{{name}} 학생은 바둑 학습에 집중하며 매 수업마다 눈에 띄는 발전을 이루고 있습니다.',
    ),

    // 1. 학습 성취 (Achievement) - 수준별로 구분
    // [입문/기초 - Level 1]
    CommentTemplateModel(
      id: 'a1',
      category: '학습 성취',
      level: 1,
      content: '기초 규칙을 완벽히 이해하고 돌의 활로와 집의 개념을 정확히 구분하여 적용합니다.',
    ),
    CommentTemplateModel(
      id: 'a10',
      category: '학습 성취',
      level: 1,
      content: '단수와 따내기 등 바둑의 가장 기본이 되는 원리를 실전 대국에서 실수 없이 수행해냅니다.',
    ),
    CommentTemplateModel(
      id: 'a11',
      category: '학습 성취',
      level: 1,
      content: '착수 금지와 패의 규칙 등 자칫 헷갈리기 쉬운 부분들도 이제는 정확히 숙지하고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a100',
      category: '학습 성취',
      level: 1,
      content: '두 집을 만들어야 산다는 삶과 죽음의 기본 개념을 이해하고 실전에서 적용하려 노력합니다.',
    ),
    CommentTemplateModel(
      id: 'a101',
      category: '학습 성취',
      level: 1,
      content: '상대방 돌을 잡는 것에만 몰두하지 않고 내 돌을 연결하여 튼튼하게 만드는 법을 익히고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a102',
      category: '학습 성취',
      level: 1,
      content: '서로 단수에 걸린 상황에서 침착하게 먼저 따내는 수를 찾아내는 감각이 좋아졌습니다.',
    ),
    CommentTemplateModel(
      id: 'a103',
      category: '학습 성취',
      level: 1,
      content: '바둑판의 귀와 변, 중앙의 명칭을 명확히 알고 있으며 첫 수를 어디에 두어야 할지 이해하고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a104',
      category: '학습 성취',
      level: 1,
      content: '내 돌이 위험할 때 달아나는 방법과 상대 돌을 포위하는 방법을 구별하여 사용할 줄 압니다.',
    ),
    CommentTemplateModel(
      id: 'a105',
      category: '학습 성취',
      level: 1,
      content: '옥집과 진짜 집을 구별하는 눈을 가지게 되었으며, 집을 짓는 기초 원리를 잘 따르고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a106',
      category: '학습 성취',
      level: 1,
      content: '끝내기의 개념을 조금씩 배워가며, 대국이 끝난 후 스스로 집을 세어보는 연습을 하고 있습니다.',
    ),

    // [초급/실전 - Level 2]
    CommentTemplateModel(
      id: 'a2',
      category: '학습 성취',
      level: 2,
      content: '착점의 우선순위인 \'큰 자리\'를 스스로 찾아내며 형세를 분석하는 안목이 생겼습니다.',
    ),
    CommentTemplateModel(
      id: 'a12',
      category: '학습 성취',
      level: 2,
      content: '축과 장문, 환격 등 기본적인 맥점을 발견하고 이를 이용해 이득을 보는 감각이 매우 좋습니다.',
    ),
    CommentTemplateModel(
      id: 'a13',
      category: '학습 성취',
      level: 2,
      content: '집 짓기의 효율성을 이해하기 시작했으며, 돌이 끊기지 않도록 연결하는 능력이 향상되었습니다.',
    ),
    CommentTemplateModel(
      id: 'a200',
      category: '학습 성취',
      level: 2,
      content: '수상전 상황에서 상대의 수를 줄이고 나의 수를 늘리는 요령을 터득하여 승률이 높아졌습니다.',
    ),
    CommentTemplateModel(
      id: 'a201',
      category: '학습 성취',
      level: 2,
      content: '빈삼각과 같은 나쁜 모양을 피하고 호구와 같은 탄력 있는 좋은 모양을 갖추려 노력합니다.',
    ),
    CommentTemplateModel(
      id: 'a202',
      category: '학습 성취',
      level: 2,
      content: '상대의 세력을 삭감하거나 내 영역을 넓히는 행마법을 실전에서 자연스럽게 구사합니다.',
    ),
    CommentTemplateModel(
      id: 'a203',
      category: '학습 성취',
      level: 2,
      content: '포석 단계에서 귀-변-중앙의 순서로 집을 넓혀가는 기본 원리를 잘 지키고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a204',
      category: '학습 성취',
      level: 2,
      content: '침입해온 상대 돌을 무조건 잡으러 가기보다 공격을 통해 이득을 취하는 유연한 사고가 돋보입니다.',
    ),
    CommentTemplateModel(
      id: 'a205',
      category: '학습 성취',
      level: 2,
      content: '간단한 사활 문제는 한 눈에 정답을 찾아낼 정도로 기본적인 수읽기 속도가 빨라졌습니다.',
    ),
    CommentTemplateModel(
      id: 'a206',
      category: '학습 성취',
      level: 2,
      content: '패를 활용하여 불리한 상황을 반전시키거나 상대를 굴복시키는 전술적 활용 능력이 생겼습니다.',
    ),

    // [중고급/심화 - Level 3]
    CommentTemplateModel(
      id: 'a3',
      category: '학습 성취',
      level: 3,
      content: '복잡한 사활 문제도 침착하게 수읽기하여 정답을 찾아내는 해결 능력이 우수합니다.',
    ),
    CommentTemplateModel(
      id: 'a14',
      category: '학습 성취',
      level: 3,
      content: '중반 전투 시 상대의 약점을 예리하게 파고드는 공격적인 수읽기가 돋보입니다.',
    ),
    CommentTemplateModel(
      id: 'a15',
      category: '학습 성취',
      level: 3,
      content: '형세 판단을 통해 현재의 유불리를 파악하고, 그에 맞는 전략을 세우는 능력이 탁월합니다.',
    ),
    CommentTemplateModel(
      id: 'a300',
      category: '학습 성취',
      level: 3,
      content: '부분적인 전투 승리보다 전체적인 판의 균형을 중시하는 대세관이 형성되고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a301',
      category: '학습 성취',
      level: 3,
      content: '상대의 의도를 미리 파악하고 그에 대응하는 반격 수단을 준비하는 등 수읽기의 깊이가 깊어졌습니다.',
    ),
    CommentTemplateModel(
      id: 'a302',
      category: '학습 성취',
      level: 3,
      content: '두터움을 활용하여 장기적인 이득을 도모하거나 상대를 압박하는 운영 능력이 수준급입니다.',
    ),
    CommentTemplateModel(
      id: 'a303',
      category: '학습 성취',
      level: 3,
      content: '사석 작전을 통해 불필요한 돌을 버리고 더 큰 이익을 취하는 고도의 전술을 구사하기도 합니다.',
    ),
    CommentTemplateModel(
      id: 'a304',
      category: '학습 성취',
      level: 3,
      content: '정교한 끝내기 수순을 통해 미세한 승부에서도 역전승을 이끌어내는 뒷심이 강해졌습니다.',
    ),
    CommentTemplateModel(
      id: 'a305',
      category: '학습 성취',
      level: 3,
      content: '고정관념에 얽매이지 않는 창의적인 수를 시도하며 자신만의 기풍을 만들어가고 있습니다.',
    ),
    CommentTemplateModel(
      id: 'a306',
      category: '학습 성취',
      level: 3,
      content: '약한 돌을 수습하는 타개 능력이 뛰어나 위기 상황에서도 쉽게 무너지지 않는 끈기를 보여줍니다.',
    ),

    // 2. 학습 태도 (Attitude)
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
      id: 't10',
      category: '학습 태도',
      content: '패배에 실망하기보다 복기를 통해 자신의 실수를 돌아보는 진지한 자세를 갖고 있습니다.',
    ),
    CommentTemplateModel(
      id: 't11',
      category: '학습 태도',
      content: '한 수 한 수 신중하게 생각하고 두려는 노력이 보이며, 경솔한 착점이 눈에 띄게 줄었습니다.',
    ),
    CommentTemplateModel(
      id: 't12',
      category: '학습 태도',
      content: '모르는 문제가 나와도 포기하지 않고 스스로 끝까지 해결해 보려는 의지가 강합니다.',
    ),
    CommentTemplateModel(
      id: 't100',
      category: '학습 태도',
      content: '바른 자세로 앉아 흐트러짐 없이 대국에 임하며, 상대를 배려하는 마음가짐이 돋보입니다.',
    ),
    CommentTemplateModel(
      id: 't101',
      category: '학습 태도',
      content: '자신의 차례가 아닐 때도 상대의 수를 주의 깊게 관찰하며 생각하는 습관이 잘 잡혀 있습니다.',
    ),
    CommentTemplateModel(
      id: 't102',
      category: '학습 태도',
      content: '어려운 상황에서도 쉽게 포기하거나 짜증 내지 않고 차분함을 유지하는 마인드 컨트롤 능력이 좋습니다.',
    ),
    CommentTemplateModel(
      id: 't103',
      category: '학습 태도',
      content: '과제를 성실하게 수행해 오며, 배운 내용을 복습하려는 자기 주도적인 학습 태도를 갖추고 있습니다.',
    ),
    CommentTemplateModel(
      id: 't104',
      category: '학습 태도',
      content: '친구들과의 대국이나 교류 활동에도 적극적으로 참여하며 즐겁게 바둑을 배우고 있습니다.',
    ),
    CommentTemplateModel(
      id: 't105',
      category: '학습 태도',
      content: '선생님의 조언을 열린 마음으로 받아들이고 즉시 자신의 플레이에 적용하려는 유연함이 장점입니다.',
    ),

    // 3. 격려 (Encouragement)
    CommentTemplateModel(
      id: 'enc1',
      category: '격려',
      content: '앞으로도 지금처럼 꾸준히 노력한다면 반드시 목표한 급수에 도달할 수 있을 것입니다.',
    ),
    CommentTemplateModel(
      id: 'enc2',
      category: '격려',
      content: '바둑을 통해 배운 집중력과 끈기가 다른 분야에서도 큰 도움이 될 것이라 확신합니다.',
    ),
    CommentTemplateModel(
      id: 'enc3',
      category: '격려',
      content: '{{name}} 학생의 무한한 가능성을 믿으며, 앞으로도 즐겁게 바둑을 배워나가길 바랍니다.',
    ),
    CommentTemplateModel(
      id: 'enc4',
      category: '격려',
      content: '다음 달에는 더욱 성장한 모습으로 만날 수 있기를 기대합니다.',
    ),
    CommentTemplateModel(
      id: 'enc5',
      category: '격려',
      content: '바둑을 사랑하는 마음을 잃지 않고 계속 정진한다면 훌륭한 기사가 될 것입니다.',
    ),
    CommentTemplateModel(
      id: 'enc6',
      category: '격려',
      content: '가정에서도 {{name}} 학생의 노력을 격려해 주시고 함께 응원해 주시기 바랍니다.',
    ),
    CommentTemplateModel(
      id: 'enc7',
      category: '격려',
      content: '지금의 열정을 계속 이어간다면 머지않아 큰 성과를 거둘 수 있을 것입니다.',
    ),
    CommentTemplateModel(
      id: 'enc8',
      category: '격려',
      content: '{{name}} 학생의 밝은 미래를 응원하며, 최선을 다해 지도하겠습니다.',
    ),
  ];
}
