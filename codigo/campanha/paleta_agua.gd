extends RefCounted

## Paleta da água por estação, do escuro ao brilho (a média de cada faixa de luminância da animação antiga).
## Compartilhada pela Bacia do Moinho e pelas regiões que reutilizam a água dela.
const TONS := [
	[Vector3(.089,.334,.384), Vector3(.095,.354,.408), Vector3(.104,.383,.439), Vector3(.158,.441,.495), Vector3(.243,.507,.555)],
	[Vector3(.082,.372,.392), Vector3(.087,.394,.416), Vector3(.097,.423,.446), Vector3(.150,.479,.504), Vector3(.237,.537,.560)],
	[Vector3(.116,.307,.349), Vector3(.123,.324,.370), Vector3(.133,.349,.398), Vector3(.188,.409,.457), Vector3(.266,.482,.524)],
	[Vector3(.116,.272,.368), Vector3(.123,.289,.390), Vector3(.133,.312,.420), Vector3(.188,.375,.476), Vector3(.266,.454,.540)]]
