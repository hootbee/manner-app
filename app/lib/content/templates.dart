// 위치 템플릿이 아는 자리 id (ADR 0003 §6). 견본 docs/prototype/index.html의 템플릿 그림과 같다.
const templateSpots = <String, Set<String>>{
  'sidewalk': {'inner', 'outer'},
  'alley': {'wall', 'carside'},
  'stairs': {'above', 'same', 'below'},
};

// 블라인드 풀이에서 감출 키와 섞을 배열 (ADR 0009 §4). 형식이 늘어 답이 담긴 필드가 생기면 여기만 고친다.
const blindHidden = {'answer', 'grade', 'note', 'feedback', 'evidence'}; // 어느 깊이에 있든 지운다
const blindShuffled = {'options', 'cards'}; // 순서가 답이거나 답을 흘리는 배열은 섞는다
