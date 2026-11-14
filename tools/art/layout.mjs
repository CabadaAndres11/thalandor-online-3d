// UV layout of Kenney Blocky Characters 2.0 textures (1024×1024, 16 px per voxel).
// Measured on the labelled texture sheets; shared by every character of the pack.

export const SIZE = 1024;
export const PX = 16; // pixels per voxel

// Head: 8×8×8 voxels → 128 px faces in a cross.
export const HEAD = {
  top: [128, 0, 128, 128],
  left: [0, 128, 128, 128],
  front: [128, 128, 128, 128],
  right: [256, 128, 128, 128],
  back: [384, 128, 128, 128],
  bottom: [128, 256, 128, 128],
};
export const HEAD_AREA = [0, 0, 512, 384];

// Torso: 8 wide × 9 tall × 6 deep.
export const TORSO = {
  top: [96, 688, 128, 96],
  left: [0, 784, 96, 144],
  front: [96, 784, 128, 144],
  right: [224, 784, 96, 144],
  back: [320, 784, 128, 144],
  bottom: [96, 928, 128, 96],
};

// Arms: 4×4 section, 11 tall. Strip of four 64-px side faces under two 64-px caps.
// The last 2 voxels (32 px) of each side face are the hand.
export const ARMS = { left: [768, 534], right: [480, 534] };
export const ARM_CAP_TOP = [0, 0, 64, 64]; // shoulder (sleeve), relative to the arm origin
export const ARM_CAP_BOTTOM = [64, 0, 64, 64]; // underside of the hand (skin)
export const ARM_SIDES = [0, 64, 256, 176];
export const HAND_PX = 32;

// Legs: 4×4 section, 10 tall. The last voxel is the shoe.
export const LEGS = { left: [768, 800], right: [480, 800] };
export const LEG_CAP_TOP = [0, 0, 64, 64];
export const LEG_CAP_BOTTOM = [64, 0, 64, 64];
export const LEG_SIDES = [0, 64, 256, 160];

// Front face features of the head (absolute pixels).
export const EYES = [[154, 187, 18, 18], [214, 187, 18, 18]];
export const BROWS = [[150, 166, 30, 12], [206, 166, 30, 12]];
export const MOUTH = [180, 220, 26, 8];
export const NOSE = [176, 194, 34, 24];
