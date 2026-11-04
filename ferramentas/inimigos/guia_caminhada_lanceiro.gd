extends SceneTree
func _initialize():
	var pernas = [ [[305,380,370,448],[190,390,135,448]], [[270,384,260,448],[240,368,180,414]], [[220,385,175,448],[285,365,295,420]], [[195,390,135,448],[305,380,370,448]], [[240,368,180,414],[270,384,260,448]], [[285,365,295,420],[220,385,175,448]] ]
	var svg = '<svg xmlns="http://www.w3.org/2000/svg" width="1536" height="1024"><rect width="1536" height="1024" fill="#202930"/>'
	for q in 6:
		var x=(q%3)*512
		var y=(q/3)*512
		svg += '<g transform="translate(%d,%d)"><path d="M40 448H472" stroke="#aaa" stroke-width="2"/><path d="M256 220V320" stroke="white" stroke-width="12"/>' % [x,y]
		for j in [1,0]:
			var p=pernas[q][j]
			var cor="#ffad42" if j==0 else "#52b9ff"
			svg += '<path d="M%d 320L%d %dL%d %d" fill="none" stroke="%s" stroke-width="16"/><circle cx="%d" cy="%d" r="10" fill="%s"/>' % [280 if j==0 else 244,p[0],p[1],p[2],p[3],cor,p[2],p[3],cor]
		svg += '<text x="40" y="50" fill="white" font-size="24">%d</text><text x="40" y="85" fill="#ffad42" font-size="18">NEAR LEG</text><text x="40" y="112" fill="#52b9ff" font-size="18">FAR LEG</text></g>' % (q+1)
	svg+='</svg>'
	var im=Image.new()
	im.load_svg_from_string(svg)
	im.save_png('res://arte/fontes/inimigos/goblins_moinho/lanceiro/guia_pernas_direita.png')
	quit()
