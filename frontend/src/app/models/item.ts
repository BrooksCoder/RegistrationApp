export interface Item {
  id: number;
  name: string;
  description: string;
  status?: string; // Pending, Approved, Rejected
  imageUrl?: string;
  createdAt: Date;
  updatedAt?: Date;
}
