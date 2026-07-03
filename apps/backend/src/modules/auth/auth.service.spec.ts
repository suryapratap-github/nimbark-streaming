import { ConflictException, UnauthorizedException } from '@nestjs/common';
import { UserRole } from '@prisma/client';
import * as bcrypt from 'bcryptjs';
import { AuthService } from './auth.service';

describe('AuthService', () => {
  const jwt = {
    signAsync: jest.fn().mockResolvedValue('signed-token')
  };
  const config = {
    get: jest.fn().mockReturnValue('7d')
  };
  const prisma = {
    user: {
      findFirst: jest.fn(),
      findUnique: jest.fn(),
      create: jest.fn()
    }
  };
  const service = new AuthService(prisma as never, jwt as never, config as never);

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('registers a viewer with normalized email and username', async () => {
    prisma.user.findFirst.mockResolvedValue(null);
    prisma.user.create.mockImplementation(({ data }) =>
      Promise.resolve({
        id: 'user-1',
        email: data.email,
        username: data.username,
        displayName: data.displayName,
        passwordHash: data.passwordHash,
        bio: null,
        role: data.role,
        avatarUrl: null
      })
    );

    const response = await service.register({
      email: 'Viewer@Example.COM',
      password: 'password123',
      displayName: ' Viewer One ',
      username: 'Viewer One!'
    });

    expect(prisma.user.findFirst).toHaveBeenCalledWith({
      where: {
        OR: [{ email: 'viewer@example.com' }, { username: 'viewerone' }]
      },
      select: { id: true }
    });
    expect(prisma.user.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        email: 'viewer@example.com',
        username: 'viewerone',
        displayName: 'Viewer One',
        role: UserRole.USER
      })
    });
    expect(response).toMatchObject({
      accessToken: 'signed-token',
      tokenType: 'Bearer',
      expiresIn: '7d',
      user: {
        id: 'user-1',
        email: 'viewer@example.com',
        username: 'viewerone',
        role: UserRole.USER
      }
    });
  });

  it('rejects duplicate email or username during registration', async () => {
    prisma.user.findFirst.mockResolvedValue({ id: 'existing-user' });

    await expect(
      service.register({
        email: 'taken@example.com',
        password: 'password123',
        displayName: 'Taken',
        username: 'taken'
      })
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.user.create).not.toHaveBeenCalled();
  });

  it('logs in active users with a valid password', async () => {
    const passwordHash = await bcrypt.hash('password123', 4);
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      email: 'viewer@example.com',
      username: 'viewer',
      displayName: 'Viewer',
      passwordHash,
      role: UserRole.USER,
      bio: null,
      avatarUrl: null,
      isActive: true
    });

    const response = await service.login({
      email: 'VIEWER@example.com',
      password: 'password123'
    });

    expect(prisma.user.findUnique).toHaveBeenCalledWith({
      where: { email: 'viewer@example.com' }
    });
    expect(response.accessToken).toBe('signed-token');
  });

  it('rejects inactive users and invalid passwords', async () => {
    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      email: 'viewer@example.com',
      username: 'viewer',
      displayName: 'Viewer',
      passwordHash: await bcrypt.hash('password123', 4),
      role: UserRole.USER,
      bio: null,
      avatarUrl: null,
      isActive: false
    });

    await expect(service.login({ email: 'viewer@example.com', password: 'password123' })).rejects.toBeInstanceOf(
      UnauthorizedException
    );

    prisma.user.findUnique.mockResolvedValue({
      id: 'user-1',
      email: 'viewer@example.com',
      username: 'viewer',
      displayName: 'Viewer',
      passwordHash: await bcrypt.hash('password123', 4),
      role: UserRole.USER,
      bio: null,
      avatarUrl: null,
      isActive: true
    });

    await expect(service.login({ email: 'viewer@example.com', password: 'wrong-password' })).rejects.toBeInstanceOf(
      UnauthorizedException
    );
  });
});
