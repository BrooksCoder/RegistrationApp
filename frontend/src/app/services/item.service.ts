import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { Item } from '../models/item';

export interface AuditLog {
  id: string;
  itemId: number;
  action: 'CREATE' | 'UPDATE' | 'DELETE' | 'UPLOAD' | 'DOWNLOAD' | 'APPROVE' | 'REJECT';
  details: string;
  changedBy: string;
  timestamp: Date;
}

export interface Notification {
  id: string;
  subject: string;
  recipientEmail: string;
  status: 'Pending' | 'Sent' | 'Failed';
  timestamp: Date;
}

@Injectable({
  providedIn: 'root'
})
export class ItemService {
  private apiUrl = '/api/items'; // Backend URL - proxied by Nginx
  private auditUrl = '/api/audit';
  private notificationUrl = '/api/notifications';
  private analyticsUrl = '/api/analytics';
  private approvalsUrl = '/api/approvals';

  constructor(private http: HttpClient) { }

  // ========== ITEM OPERATIONS ==========
  getItems(): Observable<Item[]> {
    return this.http.get<Item[]>(this.apiUrl);
  }

  addItem(item: Omit<Item, 'id' | 'createdAt' | 'updatedAt'>): Observable<Item> {
    return this.http.post<Item>(this.apiUrl, item);
  }

  addItemWithImage(formData: FormData): Observable<Item> {
    return this.http.post<Item>(`${this.apiUrl}/with-image`, formData);
  }

  deleteItem(id: number): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/${id}`);
  }

  updateItem(id: number, item: Partial<Item>): Observable<Item> {
    return this.http.put<Item>(`${this.apiUrl}/${id}`, item);
  }

  // ========== APPROVAL OPERATIONS ==========
  approveItem(id: number): Observable<Item> {
    return this.http.post<Item>(`${this.approvalsUrl}/${id}/approve`, {});
  }

  rejectItem(id: number): Observable<Item> {
    return this.http.post<Item>(`${this.approvalsUrl}/${id}/reject`, {});
  }

  getPendingApprovals(): Observable<Item[]> {
    return this.http.get<Item[]>(`${this.approvalsUrl}/pending`);
  }

  // ========== AUDIT LOG OPERATIONS ==========
  getAuditLogs(itemId?: number): Observable<AuditLog[]> {
    const url = itemId ? `${this.auditUrl}/${itemId}` : this.auditUrl;
    return this.http.get<AuditLog[]>(url);
  }

  logAction(itemId: number, action: AuditLog['action'], details: string): Observable<AuditLog> {
    return this.http.post<AuditLog>(this.auditUrl, {
      itemId,
      action,
      details,
      changedBy: 'System',
      timestamp: new Date()
    });
  }

  // ========== NOTIFICATION OPERATIONS ==========
  getNotifications(): Observable<Notification[]> {
    return this.http.get<Notification[]>(this.notificationUrl);
  }

  getNotificationStats(): Observable<{ queued: number; sent: number; failed: number }> {
    return this.http.get<{ queued: number; sent: number; failed: number }>(`${this.notificationUrl}/stats`);
  }

  // ========== ANALYTICS OPERATIONS ==========
  getAnalytics(): Observable<{
    totalItems: number;
    storageUsed: number;
    queueDepth: number;
    auditCount: number;
    apiResponseTime: number;
    successRate: number;
  }> {
    return this.http.get<{
      totalItems: number;
      storageUsed: number;
      queueDepth: number;
      auditCount: number;
      apiResponseTime: number;
      successRate: number;
    }>(this.analyticsUrl);
  }
}
