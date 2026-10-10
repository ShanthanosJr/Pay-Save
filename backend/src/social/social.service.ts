import { Injectable } from '@nestjs/common';
import { AppException } from '../common/errors/app.exception';
import { avatarUrl, sniffImageType } from '../users/image-type';
import {
  InboxRow,
  MessageKind,
  MessageRow,
  PalRequestRow,
  PalStatus,
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
  palStatus: PalStatus;
}

export type SuggestionReason =
  'shared_circle' | 'mutual_pals' | 'follows_you' | 'new';

export interface PalRequest extends Person {
  requestedAt: string;
  mutualPals: number;
}

/** Ignored requests stay pending for the sender; they may ask again after this. */
export const PAL_REQUEST_COOLDOWN_DAYS = 21;
/** Open outgoing requests a member may have at once (anti-spam). */
export const MAX_PENDING_PAL_REQUESTS = 100;

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
  palsCount: number;
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
  kind: MessageKind;
  /** Taken back by its sender; body and media are gone. */
  deleted: boolean;
  media: { url: string; contentType: string; size: number } | null;
  starred: boolean;
  reactions: { emoji: string; count: number; mine: boolean }[];
}

export interface ChatSummary {
  id: string;
  peer: Person;
  lastMessage: ChatMessage;
  unread: number;
  pinned: boolean;
  favourite: boolean;
}

export const REACTIONS = ['👍', '❤️', '😂', '😮', '😢', '🙏'] as const;
export const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
export const MAX_VIDEO_BYTES = 25 * 1024 * 1024;

/** MP4/MOV carry `ftyp` at byte 4; WebM starts with the EBML header. */
export function sniffVideoType(buf: Buffer): string | null {
  if (buf.length >= 12 && buf.toString('ascii', 4, 8) === 'ftyp')
    return buf.toString('ascii', 8, 10) === 'qt'
      ? 'video/quicktime'
      : 'video/mp4';
  if (buf.length >= 4 && buf.readUInt32BE(0) === 0x1a45dfa3)
    return 'video/webm';
  return null;
}

const toPerson = (r: PersonRow): Person => ({
  id: r.id,
  fullName: r.name,
  username: r.username,
  avatarUrl: avatarUrl(r.id, r.avatar_updated_at),
  verified: r.verified,
  isFollowing: r.is_following,
  followsYou: r.follows_you,
  palStatus: r.pal_status,
});

const toMessage = (conversationId: string, m: MessageRow): ChatMessage => ({
  id: m.id,
  seq: Number(m.seq),
  senderId: m.sender_id,
  clientMessageId: m.client_message_id,
  body: m.body,
  createdAt: m.created_at.toISOString(),
  kind: m.kind,
  deleted: m.deleted_at !== null,
  media:
    m.media_type && m.media_size && !m.deleted_at
      ? {
          url: `/chats/${conversationId}/messages/${m.id}/media`,
          contentType: m.media_type,
          size: m.media_size,
        }
      : null,
  starred: m.starred,
  reactions: m.reactions,
});

const reasonFor = (r: SuggestionRow): SuggestionReason =>
  r.shared_circles > 0
    ? 'shared_circle'
    : r.mutual_count > 0
      ? 'mutual_pals'
      : r.follows_you
        ? 'follows_you'
        : 'new';

const notFound = () => new AppException(404, 'NOT_FOUND', 'Not found');
const noRequest = () =>
  new AppException(404, 'NO_PAL_REQUEST', 'No pal request or connection');

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
      palsCount: r.pals_count,
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

  async pals(me: string, id: string): Promise<Person[]> {
    await this.profile(me, id);
    return (await this.repo.pals(me, id, 100)).map(toPerson);
  }

  // ---------- pal requests ----------

  async palRequests(
    me: string,
  ): Promise<{ received: PalRequest[]; sent: PalRequest[] }> {
    const toRequest = (r: PalRequestRow): PalRequest => ({
      ...toPerson(r),
      requestedAt: r.requested_at.toISOString(),
      mutualPals: r.mutual_pals,
    });
    const [received, sent] = await Promise.all([
      this.repo.palRequests(me, 'received', 200),
      this.repo.palRequests(me, 'sent', 200),
    ]);
    return { received: received.map(toRequest), sent: sent.map(toRequest) };
  }

  async palRequestCount(me: string): Promise<{ received: number }> {
    return { received: await this.repo.receivedPalRequestCount(me) };
  }

  /** Ask to be pals; if they already asked you, you become pals at once. */
  async requestPal(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    if (await this.repo.isBlockedEitherWay(me, id))
      throw new AppException(403, 'BLOCKED', 'You cannot add this person');
    const current = (await this.profile(me, id)).palStatus;
    if (
      current === 'none' &&
      (await this.repo.sentPalRequestCount(me)) >= MAX_PENDING_PAL_REQUESTS
    )
      throw new AppException(
        429,
        'TOO_MANY_PAL_REQUESTS',
        'Too many pending pal requests. Withdraw some first',
      );
    await this.repo.requestPal(me, id, PAL_REQUEST_COOLDOWN_DAYS);
    return this.profile(me, id);
  }

  async acceptPal(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    if (!(await this.repo.acceptPal(me, id))) throw noRequest();
    return this.profile(me, id);
  }

  /** Quietly declines: the sender is not told and still sees "Pending". */
  async ignorePal(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    if (!(await this.repo.ignorePal(me, id))) throw noRequest();
    return this.profile(me, id);
  }

  /** Withdraws my pending request, or ends an existing pal connection. */
  async endPal(me: string, id: string): Promise<PublicProfile> {
    await this.assertOther(me, id);
    const ended =
      (await this.repo.withdrawPal(me, id)) ||
      (await this.repo.removePal(me, id));
    if (!ended) throw noRequest();
    return this.profile(me, id);
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
      pinned: r.pinned,
      favourite: r.favourite,
      lastMessage: {
        id: '',
        seq: Number(r.last_seq),
        senderId: r.last_sender_id,
        clientMessageId: '',
        body: r.last_body,
        createdAt: r.last_at.toISOString(),
        kind: r.last_kind,
        deleted: r.last_deleted,
        media: null,
        starred: false,
        reactions: [],
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
    const rows = await this.repo.messages(conversationId, me, {
      before: page.before,
      after: page.after,
      limit: page.limit ?? 50,
    });
    return {
      messages: rows.map((r) => toMessage(conversationId, r)),
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
    return toMessage(conversationId, m);
  }

  /** A photo or a short video, identified by its bytes, not its file name. */
  async sendMedia(
    me: string,
    conversationId: string,
    clientMessageId: string,
    caption: string,
    file: Buffer | undefined,
  ): Promise<ChatMessage> {
    const peerId = await this.peerOrThrow(me, conversationId);
    if (await this.repo.isBlockedEitherWay(me, peerId))
      throw new AppException(403, 'BLOCKED', 'You cannot message this person');
    if (!file || file.length === 0)
      throw new AppException(400, 'FILE_REQUIRED', 'Choose a photo or video');
    const image = sniffImageType(file);
    const video = image ? null : sniffVideoType(file);
    if (!image && !video)
      throw new AppException(
        415,
        'UNSUPPORTED_MEDIA',
        'Send a JPEG, PNG or WebP photo, or an MP4, MOV or WebM video',
      );
    if (file.length > (image ? MAX_IMAGE_BYTES : MAX_VIDEO_BYTES))
      throw new AppException(413, 'FILE_TOO_LARGE', 'This file is too large');
    const m = await this.repo.send(
      conversationId,
      me,
      clientMessageId,
      caption,
      {
        kind: image ? 'image' : 'video',
        contentType: (image ?? video) as string,
        data: file,
      },
    );
    if (!m)
      throw new AppException(
        409,
        'DUPLICATE_CLIENT_ID',
        'clientMessageId was already used',
      );
    return toMessage(conversationId, m);
  }

  async media(
    me: string,
    conversationId: string,
    messageId: string,
  ): Promise<{ contentType: string; data: Buffer }> {
    await this.peerOrThrow(me, conversationId);
    const found = await this.repo.attachment(conversationId, messageId);
    if (!found) throw notFound();
    return found;
  }

  /** Only the sender can take a message back; it disappears for both. */
  async deleteMessage(
    me: string,
    conversationId: string,
    messageId: string,
  ): Promise<void> {
    await this.peerOrThrow(me, conversationId);
    if (!(await this.repo.deleteMessage(conversationId, me, messageId)))
      throw notFound();
  }

  async react(
    me: string,
    conversationId: string,
    messageId: string,
    emoji: string | null,
  ): Promise<ChatMessage> {
    const m = await this.visibleMessage(me, conversationId, messageId);
    if (m.deleted_at) throw notFound();
    await this.repo.setReaction(messageId, me, emoji);
    return this.reload(me, conversationId, messageId);
  }

  async star(
    me: string,
    conversationId: string,
    messageId: string,
    starred: boolean,
  ): Promise<ChatMessage> {
    await this.visibleMessage(me, conversationId, messageId);
    await this.repo.setStar(messageId, me, starred);
    return this.reload(me, conversationId, messageId);
  }

  async setChatFlags(
    me: string,
    conversationId: string,
    flags: { pinned?: boolean; favourite?: boolean },
  ): Promise<void> {
    await this.peerOrThrow(me, conversationId);
    await this.repo.setChatFlags(conversationId, me, flags);
  }

  /** Clears the chat from my inbox only; the other person keeps theirs. */
  async clearChat(me: string, conversationId: string): Promise<void> {
    await this.peerOrThrow(me, conversationId);
    await this.repo.clearChat(conversationId, me);
  }

  private async visibleMessage(
    me: string,
    conversationId: string,
    messageId: string,
  ) {
    await this.peerOrThrow(me, conversationId);
    const m = await this.repo.message(conversationId, me, messageId);
    if (!m) throw notFound();
    return m;
  }

  private async reload(me: string, conversationId: string, messageId: string) {
    const m = await this.repo.message(conversationId, me, messageId);
    if (!m) throw notFound();
    return toMessage(conversationId, m);
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
