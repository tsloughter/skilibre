"""Blender source of truth. Run: blender -b --python tools/build_assets.py.
Creates editable art/snow_pals.blend and ready-to-import assets/models/*.glb.
All geometry and materials are original; no downloaded model dependencies.
"""
import bpy
import math
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)
for c in list(bpy.data.collections):
    if c.name != 'Collection':
        bpy.data.collections.remove(c)

def mat(name, hex_color):
    srgb = tuple(int(hex_color[i:i+2], 16) / 255 for i in (0, 2, 4))
    rgb = tuple(c / 12.92 if c < .04045 else ((c + .055) / 1.055) ** 2.4 for c in srgb)
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*rgb, 1)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*rgb, 1)
    bsdf.inputs['Roughness'].default_value = .8
    return m

M = {k:mat(k,v) for k,v in dict(snow='F6FCFF', cream='FFF0D9', fox='E88C53',
    ear='E9A6A0', ink='243D4A', pink='F0A6A6', brown='AB8067', teal='4EA9A0',
    darkteal='2E7C78', gold='FFC765', coral='E77968', blue='758FAC', wood='9D7864',
    green='75ABA1', lightgreen='A3CEC3', rock='B7C9D4').items()}
current = None

def finish(obj, name, material):
    obj.name = name
    for col in list(obj.users_collection):
        col.objects.unlink(obj)
    current.objects.link(obj)
    obj.data.materials.append(M[material])
    return obj

def sphere(name, loc, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=loc)
    o=finish(bpy.context.object, name, material)
    o.scale=scale
    for p in o.data.polygons: p.use_smooth=True
    return o

def box(name, loc, scale, material, bevel=.1):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o=finish(bpy.context.object,name,material)
    o.scale=scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod=o.modifiers.new('Soft toy edges','BEVEL'); mod.width=bevel; mod.segments=3
        o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
    return o

def cone(name, loc, radius, depth, material, radius_top=0):
    bpy.ops.mesh.primitive_cone_add(vertices=12, radius1=radius, radius2=radius_top, depth=depth, location=loc)
    return finish(bpy.context.object,name,material)

def line(name, points, material, width=.025):
    data=bpy.data.curves.new(name,'CURVE'); data.dimensions='3D'; data.bevel_depth=width; data.bevel_resolution=3
    s=data.splines.new('POLY'); s.points.add(len(points)-1)
    for p,co in zip(s.points,points): p.co=(*co,1)
    o=bpy.data.objects.new(name,data); current.objects.link(o); data.materials.append(M[material])
    return o

def start(name):
    global current
    current=bpy.data.collections.new(name); bpy.context.scene.collection.children.link(current)

def export(name):
    bpy.ops.object.select_all(action='DESELECT')
    for o in current.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=next(iter(current.objects))
    bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models'/f'{name}.glb'),
        export_format='GLB', use_selection=True, export_apply=True, export_animations=False)

def animal(kind):
    start(kind)
    fur={'fox':'fox','bunny':'cream','bear':'brown','penguin':'ink'}[kind]
    scarf={'fox':'teal','bunny':'coral','bear':'blue','penguin':'gold'}[kind]
    for side in [-1,1]:
        x=side*.34
        box('Candy-colored ski',(x,-.1,.1),(.19,2.0,.11),scarf,.07)
        sphere('Upturned ski tip',(x,-1.06,.15),(.095,.23,.12),scarf)
        sphere('Boot',(x,-.02,.31),(.24,.32,.22),'ink')
        sphere('Mitten',(side*.7,-.13,1.02),(.19,.22,.22),scarf)
        arm=sphere('Sleeve',(side*.53,.01,1.15),(.22,.25,.4),fur); arm.rotation_euler[1]=side*.5
        line('Ski pole',[(side*.8,-.12,1.02),(side*.95,.55,.13)],'wood',.025)
        sphere('Pole basket',(side*.95,.55,.16),(.11,.11,.025),'cream')
    sphere('Round tummy',(0,.02,.99),(.56,.44,.69),fur)
    sphere('Soft bib',(0,-.376,1.05),(.4,.12,.48),'cream')
    if kind=='fox':
        tail=sphere('Big fluffy tail',(.36,.47,.8),(.32,.55,.32),'fox'); tail.rotation_euler[2]=-.6
        sphere('Cream tail tip',(.6,.81,.84),(.24,.24,.25),'cream')
    if kind=='bunny': sphere('Cotton tail',(0,.5,.65),(.27,.23,.27),'snow')
    sphere('Head',(0,-.05,1.91),(.64,.53,.61),fur)
    if kind=='fox':
        for side in [-1,1]:
            cone('Pointy ear',(side*.43,.0,2.52),.28,.65,'fox')
            ear=cone('Inner ear',(side*.43,-.16,2.52),.16,.4,'cream'); ear.scale.y=.25
            sphere('Fluffy cheek',(side*.3,-.43,1.76),(.35,.22,.3),'cream')
    elif kind=='bunny':
        for side in [-1,1]:
            ear=sphere('Long bunny ear',(side*.29,.02,2.69),(.2,.17,.63),'cream'); ear.rotation_euler[1]=side*.17
            ear=sphere('Pink ear',(side*.29,-.134,2.73),(.105,.044,.44),'pink'); ear.rotation_euler[1]=side*.17
    elif kind=='bear':
        for side in [-1,1]:
            sphere('Round ear',(side*.48,.0,2.34),(.27,.2,.28),'brown')
            sphere('Ear center',(side*.48,-.16,2.34),(.16,.06,.16),'pink')
        sphere('Muzzle',(0,-.49,1.75),(.33,.18,.26),'cream')
    else:
        for side in [-1,1]: sphere('White face',(side*.24,-.45,1.96),(.32,.14,.39),'snow')
        sphere('Beak',(0,-.63,1.79),(.18,.21,.1),'gold')
        sphere('Hat',(0,.01,2.39),(.51,.43,.25),'coral')
        sphere('Pom pom',(0,.01,2.66),(.18,.18,.18),'cream')
    for side in [-1,1]:
        sphere('Bright eye',(side*.245,-.553,2.01),(.073,.054,.104),'ink')
        sphere('Eye sparkle',(side*.245-.018,-.600,2.05),(.021,.013,.027),'snow')
        sphere('Rosy cheek',(side*.39,-.515,1.8),(.105,.037,.062),'pink')
    if kind!='penguin':
        sphere('Button nose',(0,-.665,1.82),(.085,.065,.065),'ink' if kind!='bunny' else 'pink')
        line('Smile',[(-.13,-.604,1.69),(-.065,-.63,1.66),(0,-.641,1.69),(.065,-.63,1.66),(.13,-.604,1.69)],'ink',.013)
    bpy.ops.mesh.primitive_torus_add(major_radius=.4,minor_radius=.115,major_segments=24,minor_segments=8,location=(0,-.01,1.46))
    finish(bpy.context.object,'Cozy scarf',scarf)
    tail=box('Scarf tail',(.36,.35,1.26),(.22,.14,.63),scarf,.06); tail.rotation_euler[1]=-.3
    export(kind)

for kind in ['fox','bunny','bear','penguin']: animal(kind)

start('pine')
cone('Trunk',(0,0,.55),.2,1.1,'wood',.16)
for z,r,d in [(1.3,1.12,1.65),(2.05,.9,1.55),(2.75,.65,1.5)]:
    cone('Evergreen tier',(0,0,z),r,d,'green')
    cone('Snow cap',(0,0,z+.22),r*.87,d*.84,'snow')
export('pine')

start('rock')
sphere('Pebble',(0,0,.28),(.8,.63,.43),'rock')
sphere('Snow blanket',(0,0,.47),(.74,.59,.28),'snow')
export('rock')

start('ramp')
# A soft snow ramp, with a colorful lip visible from the overhead camera.
verts=[(-1,-1,0),(1,-1,0),(1,1,0),(-1,1,0),(-1,-1,.55),(1,-1,.55)]
faces=[(0,3,2,1),(0,1,5,4),(0,4,3),(1,2,5),(3,4,5,2)]
mesh=bpy.data.meshes.new('Ramp');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Snow jump',mesh);current.objects.link(obj);mesh.materials.append(M['snow'])
box('Sunny jump edge',(0,-1,.55),(2.1,.18,.12),'gold',.05)
export('ramp')

start('star')
verts=[]
for y in [-.1,.1]:
    for i in range(10):
        a=math.pi/2+i*math.pi/5;r=.48 if i%2==0 else .23
        verts.append((math.cos(a)*r,y,math.sin(a)*r))
faces=[tuple(reversed(range(10))),tuple(range(10,20))]
faces += [(i,(i+1)%10,(i+1)%10+10,i+10) for i in range(10)]
mesh=bpy.data.meshes.new('Five pointed star');mesh.from_pydata(verts,[],faces);mesh.update()
obj=bpy.data.objects.new('Pocket sunshine',mesh);current.objects.link(obj);mesh.materials.append(M['gold'])
bevel=obj.modifiers.new('Rounded star corners','BEVEL');bevel.width=.055;bevel.segments=3
obj.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
export('star')

# Arrange the editable asset library on a grid, after exporting local origins.
for i,col in enumerate(c for c in bpy.data.collections if c.name!='Collection'):
    for obj in col.objects: obj.location += Vector(((i%4)*4,(i//4)*5,0))
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'art/snow_pals.blend'))
print('SNOW PALS ASSETS COMPLETE')
