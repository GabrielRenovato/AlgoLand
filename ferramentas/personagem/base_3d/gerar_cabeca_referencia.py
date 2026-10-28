#!/usr/bin/env python3
"""Reconstrói o volume da cabeça pelas silhuetas das quatro vistas da referência.

Somente geometria/UVs; não redesenha nem modifica os pixels da referência.
Dependências de produção: numpy, scipy, scikit-image e pillow.
"""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import ConvexHull
from skimage.measure import marching_cubes

RAIZ = Path(__file__).resolve().parents[3]
FONTE = RAIZ / 'arte/fontes/personagens/base_3d/pintura_pixel_nitida/referencia_v1.png'
SAIDA = RAIZ / 'assets/personagens/base_3d/pintura_corpo/cabeca_referencia.json'
ESCALA = .002746
PASSO = .006


def gerar():
    imagem = np.asarray(Image.open(FONTE).convert('RGB')).astype(float)
    altura, largura = imagem.shape[:2]
    campos, centros = [], []
    for d in range(4):
        a = imagem[40:245, d*543:(d+1)*543]
        mascara = (a[:,:,0] > a[:,:,1]*1.08) & (a[:,:,0] > a[:,:,2]*1.15)
        labels, _ = ndimage.label(mascara)
        tamanhos = np.bincount(labels.ravel()); tamanhos[0] = 0
        mascara = ndimage.binary_fill_holes(labels == tamanhos.argmax())
        yy, xx = np.where(mascara)
        centros.append([(xx.min()+xx.max())/2+d*543, (yy.min()+yy.max())/2+40])
        cheia = np.zeros((altura, largura), bool)
        cheia[40:245, d*543:(d+1)*543] = mascara
        campos.append(ndimage.distance_transform_edt(~cheia) - ndimage.distance_transform_edt(cheia))
    origem = np.array([-.32, -.30, -.36])
    q = np.stack(np.meshgrid(np.arange(-.32,.321,PASSO), np.arange(-.30,.301,PASSO),
                            np.arange(-.36,.361,PASSO), indexing='ij'), axis=-1)
    inclinacao = np.radians(20)
    distancias = []
    for d in range(4):
        angulo = d*np.pi/2
        x = np.cos(angulo)*q[...,0] + np.sin(angulo)*q[...,2]
        z = -np.sin(angulo)*q[...,0] + np.cos(angulo)*q[...,2]
        y = np.cos(inclinacao)*q[...,1] - np.sin(inclinacao)*z
        u, v = centros[d][0]+x/ESCALA, centros[d][1]-y/ESCALA
        distancias.append(ndimage.map_coordinates(campos[d], [v,u], order=1, mode='constant', cval=999))
    campo = np.maximum.reduce(distancias)
    # Só quatro silhuetas deixariam a seção da cabeça quadrada. Uma seção
    # elíptica mantém as larguras frontal/lateral e arredonda as diagonais.
    secao = (np.sqrt((q[...,0]/.245)**2 + (q[...,2]/.305)**2)-1)*50
    campo = np.maximum(campo,secao)
    vertices, faces, _, _ = marching_cubes(campo, 0, spacing=(PASSO,)*3, gradient_direction='ascent')
    vertices += origem
    # O cabelo desenhado tem pequenas frestas que, na interseção de vistas,
    # viravam lâminas profundas. A cabeça precisa de um volume fechado;
    # as separações entre mechas continuam na pintura.
    casco = ConvexHull(vertices)
    faces = casco.simplices.copy()
    for i, (a,b,c) in enumerate(faces):
        if np.dot(np.cross(vertices[b]-vertices[a],vertices[c]-vertices[a]),casco.equations[i,:3])<0:
            faces[i]=[a,c,b]
    usados = np.unique(faces)
    novo_indice = np.full(len(vertices),-1)
    novo_indice[usados] = np.arange(len(usados))
    vertices = vertices[usados]
    faces = novo_indice[faces]
    normais = np.zeros_like(vertices)
    for a,b,c in faces:
        n = np.cross(vertices[b]-vertices[a], vertices[c]-vertices[a])
        for i in [a,b,c]:normais[i] += n
    normais /= np.maximum(np.linalg.norm(normais, axis=1, keepdims=True), 1e-9)
    if normais[np.argmax(vertices[:,0]),0] < 0:
        normais *= -1; faces = faces[:,::-1]
    dados = {'vertices': np.round(vertices,6).tolist(), 'normais': np.round(normais,6).tolist(),
             'faces': faces.tolist(), 'centros': centros, 'escala': ESCALA,
             'tamanho_textura': [largura,altura]}
    SAIDA.write_text(json.dumps(dados, separators=(',',':'))+'\n')
    print(f'Cabeça: {len(vertices)} vértices, {len(faces)} triângulos; quatro silhuetas da referência.')


if __name__ == '__main__':gerar()
