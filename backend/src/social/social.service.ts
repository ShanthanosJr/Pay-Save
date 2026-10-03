import { Injectable } from '@nestjs/common';
import { AppException } from '../common/errors/app.exception';
import { avatarUrl } from '../users/image-type';
import {
  InboxRow,
  MessageRow,
  PersonRow,
  ProfileRow,
  SocialRepository,
  SuggestionRow,
} from './social.repository';

export interface Person {
  id: string;
  fullName: string;
  username: string | null;
  avatarUrl: string | null;
  verified: boolean;
  isFollowing: boolean;
  followsYou: boolean;
}

export type SuggestionReason =
  'shared_circle' | 'mutual' | 'follows_you' | 'new';

export interface Suggestion extends Person {
  reason: SuggestionReason;
  sharedCircles: number;
  mutualCount: number;
}

/** What another member may see. No phone, email, NIC or age. */
export interface PublicProfile extends Person {
  bio: string | null;
  city: string | null;
  memberSince: string;
  followersCount: number;
  followingCount: number;
  sharedCircles: number;
  isMe: boolean;
  blockedByMe: boolean;
}

export interface ChatMessage {
  id: string;
  seq: number;
  senderId: string;
  clientMessageId: string;
  body: string;
  createdAt: string;
}

export interface ChatSummary {
  id: string;
  peer: Person;
  lastMessage: ChatMessage;
  unread: number;
}

const toPerson = (r: PersonRow): Person => ({
  id: r.id,
  fullName: r.name,
  username: r.username,
  avatarUrl: avatarUrl(r.id, r.avatar_updated_at),
  verified: r.verified,
  isFollowing: r.is_following,
  followsYou: r.follows_you,
});

const toMessage = (m: MessageRow): ChatMessage => ({
  id: m.id,
  seq: Number(m.seq),
  senderId: m.sender_id,
  clientMessageId: m.client_message_id,
  body: m.body,
  createdAt: m.created_at.toISOString(),
});

const reasonFor = (r: SuggestionRow): SuggestionReason =>
  r.shared_circles > 0
    ? 'shared_circle'
    : r.mutual_count > 0
      ? 'mutual'
      : r.follows_you
        ? 'follows_you'
        : 'new';

const notFound = () => new AppException(404, 'NOT_FOUND', 'Not found');

@Injectable()
export class SocialService {
  constructor(private readonly repo: SocialRepository) {}

  // ---------- people ----------

  async search(me: string, q: string): Promise<Person[]> {
    return (await this.repo.search(me, q, 20)).map(toPerson);
  }

  async suggestions(me: string): Promise<Suggestion[]> {
    return (await this.repo.suggestions(me, 20)).map((r) => ({
      ...toPerson(r),
      reason: reasonFor(r),
      sharedCircles: r.shared_circles,
      mutualCount: r.mutual_count,
    }));
  }

  /** Someone who blocked you simply does not exist for you. */
  async profile(me: string, id: string): Promise<PublicProfile> {
    const r: ProfileRow | null = await this.repo.profile(me, id);
    if (!r || r.blocked_me) throw notFound();
    return {
      ...toPerson(r),
      bio: r.bio,
      city: r.city,
      memberSince: r.created_at.toISOString(),
      followersCount: r.followers_count,
      followingCount: r.following_count,
      sharedCircles: r.shared_circles,
      isMe: r.id === me,
      blockedByMe: r.blocked_by_me,
    };
  }

  async followers(me: string, id: string): Promise<Person[]> {
    await this.profile(me, id);
    return (await this.repo.followers(me, id, 100)).map(toPerson);
  }

  async following(me: string, id: string): Promise<Person[]> {
    await this.profile(me, id);
    return (await this.repo.following(me, id, 100)).map(toPerson);
  }

  async follow(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    if (await this.repo.isBlockedEitherWay(me, id))
      throw new AppException(403, 'BLOCKED', 'You cannot follow this person');
    await this.repo.follow(me, id);
    return this.profile(me, id);
  }

  async unfollow(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    await this.repo.unfollow(me, id);
    return this.profile(me, id);
  }

  async block(me: string, id: string): Promise<void> {
    await this.assertOther(me, id);
    await this.repo.block(me, id);
  }

  async unblock(me: string, id: string): Promise<void> {
    await this.assertOther(me, id);
    await this.repo.unblock(me, id);
  }

  private async assertOther(me: string, id: string): Promise<void> {
    if (me === id)
      throw new AppException(400, 'SELF', 'You cannot do that to yourself');
    await this.profile(me, id);
  }

  // ---------- chats ----------

  async inbox(me: string): Promise<ChatSummary[]> {
    return (await this.repo.inbox(me, 100)).map((r: InboxRow) => ({
      id: r.conversation_id,
      peer: toPerson(r),
      unread: r.unread,
      lastMessage: {
        id: '',
        seq: Number(r.last_seq),
        senderId: r.last_sender_id,
        clientMessageId: '',
        body: r.last_body,
        createdAt: r.last_at.toISOString(),
      },
    }));
  }

  async unreadTotal(me: string): Promise<{ count: number }> {
    return { count: await this.repo.unreadTotal(me) };
  }

  async open(
    me: string,
    peerId: string,
  ): Promise<{ id: string; peer: Person }> {
    await this.assertOther(me, peerId);
    if (await this.repo.isBlockedEitherWay(me, peerId))
      throw new AppException(403, 'BLOCKED', 'You cannot message this person');
    const id = await this.repo.openConversation(me, peerId);
    return this.thread(me, id);
  }

  async thread(
    me: string,
    conversationId: string,
  ): Promise<{ id: string; peer: Person; blocked: boolean }> {
    const peerId = await this.peerOrThrow(me, conversationId);
    const peer = await this.repo.person(me, peerId);
    if (!peer) throw notFound();
    return {
      id: conversationId,
      peer: toPerson(peer),
      blocked: await this.repo.isBlockedEitherWay(me, peerId),
    };
  }

  async messages(
    me: string,
    conversationId: string,
    page: { before?: number; after?: number; limit?: number },
  ): Promise<{ messages: ChatMessage[]; peerLastReadSeq: number }> {
    const peerId = await this.peerOrThrow(me, conversationId);
    const rows = await this.repo.messages(conversationId, {
      before: page.before,
      after: page.after,
      limit: page.limit ?? 50,
    });
    return {
      messages: rows.map(toMessage),
      peerLastReadSeq: await this.repo.lastReadSeq(conversationId, peerId),
    };
  }

  async send(
    me: string,
    conversationId: string,
    clientMessageId: string,
    body: string,
  ): Promise<ChatMessage> {
    const peerId = await this.peerOrThrow(me, conversationId);
    if (await this.repo.isBlockedEitherWay(me, peerId))
      throw new AppException(403, 'BLOCKED', 'You cannot message this person');
    const m = await this.repo.send(conversationId, me, clientMessageId, body);
    if (!m)
      throw new AppException(
        409,
        'DUPLICATE_CLIENT_ID',
        'clientMessageId was already used',
      );
    return toMessage(m);
  }

  async markRead(
    me: string,
    conversationId: string,
  ): Promise<{ lastReadSeq: number }> {
    await this.peerOrThrow(me, conversationId);
    return { lastReadSeq: await this.repo.markRead(conversationId, me) };
  }

  /** Non-members get 404, so conversation ids reveal nothing. */
  private async peerOrThrow(me: string, conversationId: string) {
    const peer = await this.repo.peerOf(me, conversationId);
    if (!peer) throw notFound();
    return peer;
  }
}
