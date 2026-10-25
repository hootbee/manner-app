// 위치 템플릿이 아는 자리 id (ADR 0003 §6). 견본 docs/prototype/index.html의 템플릿 그림과 같다.
const templateSpots = <String, Set<String>>{
  'sidewalk': {'inner', 'outer'},
  'alley': {'wall', 'carside'},
  'stairs': {'above', 'same', 'below'},
};
