# Файл: res://settings/WorldSettings.gd
extends Resource
class_name WorldSettings

# --- Настройки из ChunkSource.gd ---
@export var world_id: int = 25
@export var chunk_size: int = 256

# --- Настройки из Main.gd ---
@export var vertex_spacing: float = 1.0
@export var region_size_hint: int = 256

# --- Настройки из ChunkRenderer.gd ---
@export var max_height: float = 30.0

# --- Настройки из ChunkStreamer.gd ---
@export var load_radius: int = 2
